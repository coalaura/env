import { countTokens as anthropicCountTokens } from "./tokenizer.js";
import { getLastUserMessage } from "./messages/query.js";

export function getCurrentTokenUsage(state, messages) {
	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];

		if (msg.info.role !== "assistant") {
			continue;
		}

		const assistantInfo = msg.info;

		if ((assistantInfo.tokens?.output || 0) <= 0) {
			continue;
		}

		if (state.lastCompaction > 0 && (msg.info.time.created < state.lastCompaction || msg.info.summary === true && msg.info.time.created === state.lastCompaction)) {
			return 0;
		}

		const input = assistantInfo.tokens?.input || 0,
			output = assistantInfo.tokens?.output || 0,
			reasoning = assistantInfo.tokens?.reasoning || 0,
			cacheRead = assistantInfo.tokens?.cache?.read || 0,
			cacheWrite = assistantInfo.tokens?.cache?.write || 0;

		return input + output + reasoning + cacheRead + cacheWrite;
	}

	return 0;
}

export function getCurrentParams(state, messages, logger) {
	const userMsg = getLastUserMessage(messages);

	if (!userMsg) {
		logger.debug("No user message found when determining current params");

		return {
			providerId: undefined,
			modelId: undefined,
			agent: undefined,
			variant: undefined
		};
	}

	const userInfo = userMsg.info,
		agent = userInfo.agent,
		providerId = userInfo.model.providerID,
		modelId = userInfo.model.modelID,
		variant = userInfo.model.variant;

	return { providerId: providerId, modelId: modelId, agent: agent, variant: variant };
}

export function countTokens(text) {
	if (!text) {
		return 0;
	}

	try {
		return anthropicCountTokens(text);
	} catch {
		return Math.round(text.length / 4);
	}
}

export function estimateTokensBatch(texts) {
	if (texts.length === 0) {
		return 0;
	}

	return countTokens(texts.join(" "));
}

export const COMPACTED_TOOL_OUTPUT_PLACEHOLDER = "[Old tool result content cleared]";

function stringifyToolContent(value) {
	return typeof value === "string" ? value : JSON.stringify(value);
}

export function extractCompletedToolOutput(part) {
	if (part?.type !== "tool" || part.state?.status !== "completed" || part.state?.output === undefined) {
		return;
	}

	if (part.state?.time?.compacted) {
		return COMPACTED_TOOL_OUTPUT_PLACEHOLDER;
	}

	return stringifyToolContent(part.state.output);
}

export function extractToolContent(part) {
	const contents = [];

	if (part?.type !== "tool") {
		return contents;
	}

	if (part.state?.input !== undefined) {
		contents.push(stringifyToolContent(part.state.input));
	}

	const completedOutput = extractCompletedToolOutput(part);

	if (completedOutput !== undefined) {
		contents.push(completedOutput);
	} else if (part.state?.status === "error" && part.state?.error) {
		contents.push(stringifyToolContent(part.state.error));
	}

	return contents;
}

export function countToolTokens(part) {
	const contents = extractToolContent(part);

	return estimateTokensBatch(contents);
}

export function getTotalToolTokens(state, toolIds) {
	let total = 0;

	for (const id of toolIds) {
		const entry = state.toolParameters.get(id);

		total += entry?.tokenCount ?? 0;
	}

	return total;
}

export function countMessageTextTokens(msg) {
	const texts = [],
		parts = Array.isArray(msg.parts) ? msg.parts : [];

	for (const part of parts) {
		if (part.type === "text") {
			texts.push(part.text);
		}
	}

	if (texts.length === 0) {
		return 0;
	}

	return estimateTokensBatch(texts);
}

export function countAllMessageTokens(msg) {
	const parts = Array.isArray(msg.parts) ? msg.parts : [],
		texts = [];

	for (const part of parts) {
		if (part.type === "text") {
			texts.push(part.text);
		} else {
			texts.push(...extractToolContent(part));
		}
	}

	if (texts.length === 0) {
		return 0;
	}

	return estimateTokensBatch(texts);
}
