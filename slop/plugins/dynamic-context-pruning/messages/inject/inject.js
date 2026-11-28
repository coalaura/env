import { formatMessageIdTag } from "../../message-ids.js";
import { compressPermission } from "../../compress-permission.js";
import {
	getLastUserMessage,
	isIgnoredUserMessage,
	isProtectedUserMessage,
	messageHasCompress
} from "../query.js";
import { saveSessionState } from "../../state/persistence.js";
import {
	appendToTextPart,
	appendToLastTextPart,
	appendToAllToolParts,
	createSyntheticTextPart,
	hasContent
} from "../utils.js";
import {
	addAnchor,
	applyAnchoredNudges,
	countMessagesAfterIndex,
	findLastNonIgnoredMessage,
	getIterationNudgeThreshold,
	getNudgeFrequency,
	getModelInfo,
	isContextOverLimits
} from "./utils.js";

export const injectCompressNudges = (state, config, logger, messages, prompts, compressionPriorities, createAnchors = true) => {
	if (compressPermission(state, config) === "deny") {
		return;
	}

	if (state.manualMode) {
		return;
	}

	if (!createAnchors) {
		applyAnchoredNudges(state, config, messages, prompts, compressionPriorities);

		return;
	}

	const lastMessage = findLastNonIgnoredMessage(messages),
		lastAssistantMessage = messages.findLast((message) => message.info.role === "assistant");

	if (lastAssistantMessage && messageHasCompress(lastAssistantMessage)) {
		state.nudges.contextLimitAnchors.clear();
		state.nudges.turnNudgeAnchors.clear();
		state.nudges.iterationNudgeAnchors.clear();

		saveSessionState(state, logger);

		return;
	}

	const { providerId: providerId, modelId: modelId } = getModelInfo(messages);

	let anchorsChanged = false;

	const { overMaxLimit: overMaxLimit, overMinLimit: overMinLimit } = isContextOverLimits(config, state, providerId, modelId, messages);

	if (!overMinLimit) {
		const hadTurnAnchors = state.nudges.turnNudgeAnchors.size > 0,
			hadIterationAnchors = state.nudges.iterationNudgeAnchors.size > 0;

		if (hadTurnAnchors || hadIterationAnchors) {
			state.nudges.turnNudgeAnchors.clear();
			state.nudges.iterationNudgeAnchors.clear();

			anchorsChanged = true;
		}
	}

	if (overMaxLimit) {
		if (lastMessage) {
			const interval = getNudgeFrequency(config),
				added = addAnchor(state.nudges.contextLimitAnchors, lastMessage.message.info.id, lastMessage.index, messages, interval);

			if (added) {
				anchorsChanged = true;
			}
		}
	} else if (overMinLimit) {
		const isLastMessageUser = lastMessage?.message.info.role === "user";

		if (isLastMessageUser && lastAssistantMessage) {
			const previousSize = state.nudges.turnNudgeAnchors.size;

			state.nudges.turnNudgeAnchors.add(lastMessage.message.info.id);
			state.nudges.turnNudgeAnchors.add(lastAssistantMessage.info.id);

			if (state.nudges.turnNudgeAnchors.size !== previousSize) {
				anchorsChanged = true;
			}
		}

		const lastUserMessage = getLastUserMessage(messages);

		if (lastUserMessage && lastMessage) {
			const lastUserMessageIndex = messages.findIndex((message) => message.info.id === lastUserMessage.info.id);

			if (lastUserMessageIndex >= 0) {
				const messagesSinceUser = countMessagesAfterIndex(messages, lastUserMessageIndex),
					iterationThreshold = getIterationNudgeThreshold(config);

				if (lastMessage.index > lastUserMessageIndex && messagesSinceUser >= iterationThreshold) {
					const interval = getNudgeFrequency(config),
						added = addAnchor(state.nudges.iterationNudgeAnchors, lastMessage.message.info.id, lastMessage.index, messages, interval);

					if (added) {
						anchorsChanged = true;
					}
				}
			}
		}
	}

	applyAnchoredNudges(state, config, messages, prompts, compressionPriorities);

	if (anchorsChanged) {
		saveSessionState(state, logger);
	}
};

export const injectMessageIds = (state, config, messages, compressionPriorities) => {
	if (compressPermission(state, config) === "deny") {
		return;
	}

	for (const message of messages) {
		if (isIgnoredUserMessage(message)) {
			continue;
		}

		const messageRef = state.messageIds.byRawId.get(message.info.id);

		if (!messageRef) {
			continue;
		}

		const isBlockedMessage = isProtectedUserMessage(config, message),
			priority = config.compress.mode === "message" && !isBlockedMessage ? compressionPriorities?.get(message.info.id)?.priority : undefined,
			tag = formatMessageIdTag(isBlockedMessage ? "BLOCKED" : messageRef, priority ? { priority: priority } : undefined, state.idFormat);

		if (message.info.role === "user") {
			let injected = false;

			for (const part of message.parts) {
				if (part.type === "text") {
					injected = appendToTextPart(part, tag) || injected;
				}
			}

			if (injected) {
				continue;
			}

			message.parts.push(createSyntheticTextPart(message, tag));

			continue;
		}

		if (message.info.role !== "assistant") {
			continue;
		}

		if (!hasContent(message)) {
			continue;
		}

		if (appendToAllToolParts(message, tag)) {
			continue;
		}

		if (appendToLastTextPart(message, tag)) {
			continue;
		}

		const syntheticPart = createSyntheticTextPart(message, tag),
			firstToolIndex = message.parts.findIndex((p) => p.type === "tool");

		if (firstToolIndex === -1) {
			message.parts.push(syntheticPart);
		} else {
			message.parts.splice(firstToolIndex, 0, syntheticPart);
		}
	}
};
