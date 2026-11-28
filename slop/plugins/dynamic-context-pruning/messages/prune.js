import { isMessageCompacted } from "../state/utils.js";
import { createSyntheticUserMessage, replaceBlockIdsWithBlocked } from "./utils.js";
import { getLastUserMessage } from "./query.js";
import { formatBlockRef } from "../message-ids.js";

const PRUNED_TOOL_OUTPUT_REPLACEMENT = "[Output removed to save context - information superseded or no longer needed]";

const PRUNED_TOOL_ERROR_INPUT_REPLACEMENT = "[input removed due to failed tool call]";

const PRUNED_QUESTION_INPUT_REPLACEMENT = "[questions removed - see output for user's answers]";

export const prune = (state, logger, config, messages, summaryBase) => {
	filterCompressedRanges(state, logger, config, messages, summaryBase);
	pruneToolOutputs(state, logger, messages);
	pruneToolInputs(state, logger, messages);
	pruneToolErrors(state, logger, messages);
};

const pruneFullTool = (state, logger, messages) => {
	const messagesToRemove = [];

	for (const msg of messages) {
		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [],
			partsToRemove = [];

		for (const part of parts) {
			if (part.type !== "tool") {
				continue;
			}

			if (!state.prune.tools.has(part.callID)) {
				continue;
			}

			if (part.tool !== "edit" && part.tool !== "write") {
				continue;
			}

			partsToRemove.push(part.callID);
		}

		if (partsToRemove.length === 0) {
			continue;
		}

		msg.parts = parts.filter((part) => part.type !== "tool" || !partsToRemove.includes(part.callID));

		if (msg.parts.length === 0) {
			messagesToRemove.push(msg.info.id);
		}
	}

	if (messagesToRemove.length > 0) {
		const result = messages.filter((msg) => !messagesToRemove.includes(msg.info.id));

		messages.length = 0;

		messages.push(...result);
	}
};

const pruneToolOutputs = (state, logger, messages) => {
	for (const msg of messages) {
		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [];

		for (const part of parts) {
			if (part.type !== "tool") {
				continue;
			}

			if (!state.prune.tools.has(part.callID)) {
				continue;
			}

			if (part.state.status !== "completed") {
				continue;
			}

			if (part.tool === "question" || part.tool === "edit" || part.tool === "write") {
				continue;
			}

			part.state.output = PRUNED_TOOL_OUTPUT_REPLACEMENT;
		}
	}
};

const pruneToolInputs = (state, logger, messages) => {
	for (const msg of messages) {
		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [];

		for (const part of parts) {
			if (part.type !== "tool") {
				continue;
			}

			if (!state.prune.tools.has(part.callID)) {
				continue;
			}

			if (part.state.status !== "completed") {
				continue;
			}

			if (part.tool !== "question") {
				continue;
			}

			if (part.state.input?.questions !== undefined) {
				part.state.input.questions = PRUNED_QUESTION_INPUT_REPLACEMENT;
			}
		}
	}
};

const pruneToolErrors = (state, logger, messages) => {
	for (const msg of messages) {
		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [];

		for (const part of parts) {
			if (part.type !== "tool") {
				continue;
			}

			if (!state.prune.tools.has(part.callID)) {
				continue;
			}

			if (part.state.status !== "error") {
				continue;
			}

			const input = part.state.input;

			if (input && typeof input === "object") {
				for (const key of Object.keys(input)) {
					if (typeof input[key] === "string") {
						input[key] = PRUNED_TOOL_ERROR_INPUT_REPLACEMENT;
					}
				}
			}
		}
	}
};

const filterCompressedRanges = (state, logger, config, messages, summaryBase) => {
	if (state.prune.messages.byMessageId.size === 0 && state.prune.messages.activeByAnchorMessageId.size === 0) {
		return;
	}

	const result = [];

	for (const msg of messages) {
		const msgId = msg.info.id,
			blockId = state.prune.messages.activeByAnchorMessageId.get(msgId),
			summary = blockId !== undefined ? state.prune.messages.blocksById.get(blockId) : undefined;

		if (summary) {
			const rawSummaryContent = summary.summary;

			if (summary.active !== true || typeof rawSummaryContent !== "string" || rawSummaryContent.length === 0) {
				logger.warn("Skipping malformed compress summary", {
					anchorMessageId: msgId,
					blockId: summary.blockId
				});
			} else {
				const msgIndex = messages.indexOf(msg),
					userMessage = getLastUserMessage(messages, msgIndex) ?? summaryBase;

				if (userMessage) {
					const userInfo = userMessage.info;

					let renderedSummary = rawSummaryContent;

					if (state.idFormat === "compact") {
						renderedSummary = renderedSummary.replace(/<dcp-message-id>b(\d+)<\/dcp-message-id>\s*$/i, (_, id) => formatBlockRef(Number(id), "compact"));
					}

					const summaryContent = config.compress.mode === "message" ? replaceBlockIdsWithBlocked(renderedSummary, state.idFormat) : renderedSummary,
						summarySeed = `${summary.blockId}:${summary.anchorMessageId}`;

					result.push(createSyntheticUserMessage(userMessage, summaryContent, summarySeed));

					logger.info("Injected compress summary", {
						anchorMessageId: msgId,
						summaryLength: summaryContent.length
					});
				} else {
					logger.warn("No user message found for compress summary", {
						anchorMessageId: msgId
					});
				}
			}
		}

		const pruneEntry = state.prune.messages.byMessageId.get(msgId);

		if (pruneEntry && pruneEntry.activeBlockIds.length > 0) {
			continue;
		}

		result.push(msg);
	}

	messages.length = 0;

	messages.push(...result);
};
