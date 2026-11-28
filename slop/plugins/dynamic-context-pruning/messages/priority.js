import { countAllMessageTokens } from "../token-utils.js";
import { isMessageCompacted } from "../state/utils.js";
import { isIgnoredUserMessage, isProtectedUserMessage, messageHasCompress } from "./query.js";

const MEDIUM_PRIORITY_MIN_TOKENS = 500;

const HIGH_PRIORITY_MIN_TOKENS = 5000;

export function buildPriorityMap(config, state, messages) {
	if (config.compress.mode !== "message") {
		return new Map;
	}

	const priorities = new Map;

	for (const message of messages) {
		if (isIgnoredUserMessage(message)) {
			continue;
		}

		if (isProtectedUserMessage(config, message)) {
			continue;
		}

		if (isMessageCompacted(state, message)) {
			continue;
		}

		const rawMessageId = message.info.id;

		if (typeof rawMessageId !== "string" || rawMessageId.length === 0) {
			continue;
		}

		const ref = state.messageIds.byRawId.get(rawMessageId);

		if (!ref) {
			continue;
		}

		const tokenCount = countAllMessageTokens(message);

		priorities.set(rawMessageId, {
			ref: ref,
			tokenCount: tokenCount,
			priority: messageHasCompress(message) ? "high" : classifyMessagePriority(tokenCount)
		});
	}

	return priorities;
}

export function classifyMessagePriority(tokenCount) {
	if (tokenCount >= HIGH_PRIORITY_MIN_TOKENS) {
		return "high";
	}

	if (tokenCount >= MEDIUM_PRIORITY_MIN_TOKENS) {
		return "medium";
	}

	return "low";
}

export function listPriorityRefsBeforeIndex(messages, priorities, anchorIndex, priority) {
	const refs = [],
		seen = new Set,
		upperBound = Math.max(0, Math.min(anchorIndex, messages.length));

	for (let index = 0; index < upperBound; index++) {
		const rawMessageId = messages[index]?.info.id;

		if (typeof rawMessageId !== "string") {
			continue;
		}

		const entry = priorities.get(rawMessageId);

		if (!entry || entry.priority !== priority || seen.has(entry.ref)) {
			continue;
		}

		seen.add(entry.ref);
		refs.push(entry.ref);
	}

	return refs;
}
