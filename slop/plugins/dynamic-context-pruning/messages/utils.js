import { createHash } from "node:crypto";
import { isMessageCompacted } from "../state/utils.js";

const SUMMARY_ID_HASH_LENGTH = 16;

const DCP_BLOCK_ID_TAG_REGEX = /(<dcp-message-id(?=[\s>])[^>]*>)b\d+(<\/dcp-message-id>)/g;

const DCP_PAIRED_TAG_REGEX = /<dcp[^>]*>[\s\S]*?<\/dcp[^>]*>/gi;

const DCP_UNPAIRED_TAG_REGEX = /<\/?dcp[^>]*>/gi;

const INJECTED_MESSAGE_ID_SUFFIX_REGEX = /(?<=\n)<dcp-message-id[^>]*>m\d+<\/dcp-message-id>\s*$/;

const HALLUCINATED_PARAMETER_SUFFIX_REGEX = /(?<=\n)m\d+<\/parameter>\s*$/;

const COMPACT_TAG_REGEX = /@(?:[1-9]\d*|b[1-9]\d*|blocked)@(?:[ \t]+\[(?:low|medium|high)\])?/gi;

const generateStableId = (prefix, seed) => {
	const hash = createHash("sha256").update(seed).digest("hex").slice(0, SUMMARY_ID_HASH_LENGTH);

	return `${prefix}_${hash}`;
};

export const createSyntheticUserMessage = (baseMessage, content, stableSeed) => {
	const userInfo = baseMessage.info,
		now = Date.now(),
		deterministicSeed = stableSeed?.trim() || userInfo.id,
		messageId = generateStableId("msg_dcp_summary", deterministicSeed),
		partId = generateStableId("prt_dcp_summary", deterministicSeed);

	return {
		info: {
			id: messageId,
			sessionID: userInfo.sessionID,
			role: "user",
			agent: userInfo.agent,
			model: userInfo.model,
			time: { created: now }
		},
		parts: [
			{
				id: partId,
				sessionID: userInfo.sessionID,
				messageID: messageId,
				type: "text",
				text: content
			}
		]
	};
};

export const createSyntheticTextPart = (baseMessage, content, stableSeed) => {
	const userInfo = baseMessage.info,
		deterministicSeed = stableSeed?.trim() || userInfo.id,
		partId = generateStableId("prt_dcp_text", deterministicSeed);

	return {
		id: partId,
		sessionID: userInfo.sessionID,
		messageID: userInfo.id,
		type: "text",
		text: content
	};
};

export const appendToLastTextPart = (message, injection) => {
	const textPart = findLastTextPart(message);

	if (!textPart) {
		return false;
	}

	return appendToTextPart(textPart, injection);
};

const findLastTextPart = (message) => {
	for (let i = message.parts.length - 1; i >= 0; i--) {
		const part = message.parts[i];

		if (part.type === "text") {
			return part;
		}
	}

	return null;
};

export const appendToTextPart = (part, injection) => {
	if (typeof part.text !== "string") {
		return false;
	}

	const normalizedInjection = injection.replace(/^\n+/, "");

	if (!normalizedInjection.trim()) {
		return false;
	}

	if (part.text.includes(normalizedInjection)) {
		return true;
	}

	const baseText = part.text.replace(/\n*$/, "");

	part.text = baseText.length > 0 ? `${baseText}

${normalizedInjection}` : normalizedInjection;

	return true;
};

export const appendToAllToolParts = (message, tag) => {
	let injected = false;

	for (const part of message.parts) {
		if (part.type === "tool") {
			injected = appendToToolPart(part, tag) || injected;
		}
	}

	return injected;
};

export const appendToToolPart = (part, tag) => {
	if (part.state?.status !== "completed" || typeof part.state.output !== "string") {
		return false;
	}

	if (part.state.output.includes(tag)) {
		return true;
	}

	part.state.output = `${part.state.output}${tag}`;

	return true;
};

export const hasContent = (message) => {
	return message.parts.some((part) => part.type === "text" && typeof part.text === "string" && part.text.trim().length > 0 || part.type === "tool" && part.state?.status === "completed" && typeof part.state.output === "string");
};

export function buildToolIdList(state, messages) {
	const toolIds = [];

	for (const msg of messages) {
		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [];

		if (parts.length > 0) {
			for (const part of parts) {
				if (part.type === "tool" && part.callID && part.tool) {
					toolIds.push(part.callID);
				}
			}
		}
	}

	state.toolIdList = toolIds;

	return toolIds;
}

export const replaceBlockIdsWithBlocked = (text, format = "xml") => {
	if (format === "compact") {
		return text.replace(/@b[1-9]\d*@/gi, "@blocked@");
	}

	return text.replace(DCP_BLOCK_ID_TAG_REGEX, "$1BLOCKED$2");
};

export const stripHallucinationsFromString = (text, format = "xml") => {
	if (format === "compact") {
		text = text.replace(COMPACT_TAG_REGEX, "");
	}

	const withoutKnownSuffixes = text.replace(INJECTED_MESSAGE_ID_SUFFIX_REGEX, "").replace(HALLUCINATED_PARAMETER_SUFFIX_REGEX, "");

	return withoutKnownSuffixes.replace(DCP_PAIRED_TAG_REGEX, "").replace(DCP_UNPAIRED_TAG_REGEX, "");
};

export const stripHallucinations = (messages, format = "xml") => {
	for (const message of messages) {
		for (const part of message.parts) {
			if (part.type === "text" && typeof part.text === "string") {
				part.text = stripHallucinationsFromString(part.text, format);
			}
		}
	}
};
