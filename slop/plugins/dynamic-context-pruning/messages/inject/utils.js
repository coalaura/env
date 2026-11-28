import {
	appendGuidanceToDcpTag,
	buildCompressedBlockGuidance,
	renderMessagePriorityGuidance
} from "../../prompts/extensions/nudge.js";
import {
	listPriorityRefsBeforeIndex
} from "../priority.js";
import {
	appendToTextPart,
	appendToLastTextPart,
	createSyntheticTextPart,
	hasContent
} from "../utils.js";
import { getLastUserMessage, isIgnoredUserMessage } from "../query.js";
import { getCurrentTokenUsage } from "../../token-utils.js";
import { getActiveSummaryTokenUsage } from "../../state/utils.js";

const MESSAGE_MODE_NUDGE_PRIORITY = "high";

export function getNudgeFrequency(config) {
	return Math.max(1, Math.floor(config.compress.nudgeFrequency || 1));
}

export function getIterationNudgeThreshold(config) {
	return Math.max(1, Math.floor(config.compress.iterationNudgeThreshold || 1));
}

export function findLastNonIgnoredMessage(messages) {
	for (let i = messages.length - 1; i >= 0; i--) {
		const message = messages[i];

		if (isIgnoredUserMessage(message)) {
			continue;
		}

		return { message: message, index: i };
	}

	return null;
}

export function countMessagesAfterIndex(messages, index) {
	let count = 0;

	for (let i = index + 1; i < messages.length; i++) {
		const message = messages[i];

		if (isIgnoredUserMessage(message)) {
			continue;
		}

		count++;
	}

	return count;
}

export function getModelInfo(messages) {
	const lastUserMessage = getLastUserMessage(messages);

	if (!lastUserMessage) {
		return {
			providerId: undefined,
			modelId: undefined
		};
	}

	const userInfo = lastUserMessage.info;

	return {
		providerId: userInfo.model.providerID,
		modelId: userInfo.model.modelID
	};
}

function resolveContextTokenLimit(config, state, providerId, modelId, threshold) {
	const parseLimitValue = (limit) => {
		if (limit === undefined) {
			return;
		}

		if (typeof limit === "number") {
			return limit;
		}

		if (!limit.endsWith("%") || state.modelContextLimit === undefined) {
			return;
		}

		const parsedPercent = parseFloat(limit.slice(0, -1));

		if (isNaN(parsedPercent)) {
			return;
		}

		const roundedPercent = Math.round(parsedPercent),
			clampedPercent = Math.max(0, Math.min(100, roundedPercent));

		return Math.round(clampedPercent / 100 * state.modelContextLimit);
	};

	const modelLimits = threshold === "max" ? config.compress.modelMaxLimits : config.compress.modelMinLimits;

	if (modelLimits && providerId !== undefined && modelId !== undefined) {
		const providerModelId = `${providerId}/${modelId}`,
			modelLimit = modelLimits[providerModelId];

		if (modelLimit !== undefined) {
			return parseLimitValue(modelLimit);
		}
	}

	const globalLimit = threshold === "max" ? config.compress.maxContextLimit : config.compress.minContextLimit;

	return parseLimitValue(globalLimit);
}

export function isContextOverLimits(config, state, providerId, modelId, messages) {
	const summaryTokenExtension = config.compress.summaryBuffer ? getActiveSummaryTokenUsage(state) : 0,
		resolvedMaxContextLimit = resolveContextTokenLimit(config, state, providerId, modelId, "max"),
		maxContextLimit = resolvedMaxContextLimit === undefined ? undefined : resolvedMaxContextLimit + summaryTokenExtension,
		minContextLimit = resolveContextTokenLimit(config, state, providerId, modelId, "min"),
		currentTokens = getCurrentTokenUsage(state, messages),
		overMaxLimit = maxContextLimit === undefined ? false : currentTokens > maxContextLimit,
		overMinLimit = minContextLimit === undefined ? true : currentTokens >= minContextLimit;

	return {
		overMaxLimit: overMaxLimit,
		overMinLimit: overMinLimit
	};
}

export function addAnchor(anchorMessageIds, anchorMessageId, anchorMessageIndex, messages, interval) {
	if (anchorMessageIndex < 0) {
		return false;
	}

	let latestAnchorMessageIndex = -1;

	for (let i = messages.length - 1; i >= 0; i--) {
		if (anchorMessageIds.has(messages[i].info.id)) {
			latestAnchorMessageIndex = i;

			break;
		}
	}

	const shouldAdd = latestAnchorMessageIndex < 0 || anchorMessageIndex - latestAnchorMessageIndex >= interval;

	if (!shouldAdd) {
		return false;
	}

	const previousSize = anchorMessageIds.size;

	anchorMessageIds.add(anchorMessageId);

	return anchorMessageIds.size !== previousSize;
}

function buildMessagePriorityGuidance(messages, compressionPriorities, anchorIndex, priority) {
	if (!compressionPriorities || compressionPriorities.size === 0) {
		return "";
	}

	const refs = listPriorityRefsBeforeIndex(messages, compressionPriorities, anchorIndex, priority),
		priorityLabel = `${priority[0].toUpperCase()}${priority.slice(1)}`;

	return renderMessagePriorityGuidance(priorityLabel, refs);
}

function injectAnchoredNudge(message, nudgeText) {
	if (!nudgeText.trim()) {
		return;
	}

	if (message.info.role === "user") {
		if (appendToLastTextPart(message, nudgeText)) {
			return;
		}

		message.parts.push(createSyntheticTextPart(message, nudgeText));

		return;
	}

	if (message.info.role !== "assistant") {
		return;
	}

	if (!hasContent(message)) {
		return;
	}

	for (const part of message.parts) {
		if (part.type === "text") {
			if (appendToTextPart(part, nudgeText)) {
				return;
			}
		}
	}

	const syntheticPart = createSyntheticTextPart(message, nudgeText),
		firstToolIndex = message.parts.findIndex((p) => p.type === "tool");

	if (firstToolIndex === -1) {
		message.parts.push(syntheticPart);
	} else {
		message.parts.splice(firstToolIndex, 0, syntheticPart);
	}
}

function collectAnchoredMessages(anchorMessageIds, messages) {
	const anchoredMessages = [];

	for (const anchorMessageId of anchorMessageIds) {
		const index = messages.findIndex((message) => message.info.id === anchorMessageId);

		if (index === -1) {
			continue;
		}

		anchoredMessages.push({
			message: messages[index],
			index: index
		});
	}

	return anchoredMessages;
}

function collectTurnNudgeAnchors(state, config, messages) {
	const turnNudgeAnchors = new Set,
		targetRole = config.compress.nudgeForce === "strong" ? "user" : "assistant";

	for (const message of messages) {
		if (!state.nudges.turnNudgeAnchors.has(message.info.id)) {
			continue;
		}

		if (message.info.role === targetRole) {
			turnNudgeAnchors.add(message.info.id);
		}
	}

	return turnNudgeAnchors;
}

function applyRangeModeAnchoredNudge(anchorMessageIds, messages, baseNudgeText, compressedBlockGuidance) {
	const nudgeText = appendGuidanceToDcpTag(baseNudgeText, compressedBlockGuidance);

	if (!nudgeText.trim()) {
		return;
	}

	for (const { message: message } of collectAnchoredMessages(anchorMessageIds, messages)) {
		injectAnchoredNudge(message, nudgeText);
	}
}

function applyMessageModeAnchoredNudge(anchorMessageIds, messages, baseNudgeText, compressionPriorities) {
	for (const { message: message, index: index } of collectAnchoredMessages(anchorMessageIds, messages)) {
		const priorityGuidance = buildMessagePriorityGuidance(messages, compressionPriorities, index, MESSAGE_MODE_NUDGE_PRIORITY),
			nudgeText = appendGuidanceToDcpTag(baseNudgeText, priorityGuidance);

		injectAnchoredNudge(message, nudgeText);
	}
}

export function applyAnchoredNudges(state, config, messages, prompts, compressionPriorities) {
	const turnNudgeAnchors = collectTurnNudgeAnchors(state, config, messages);

	if (config.compress.mode === "message") {
		applyMessageModeAnchoredNudge(state.nudges.contextLimitAnchors, messages, prompts.contextLimitNudge, compressionPriorities);
		applyMessageModeAnchoredNudge(turnNudgeAnchors, messages, prompts.turnNudge, compressionPriorities);
		applyMessageModeAnchoredNudge(state.nudges.iterationNudgeAnchors, messages, prompts.iterationNudge, compressionPriorities);

		return;
	}

	const compressedBlockGuidance = buildCompressedBlockGuidance(state);

	applyRangeModeAnchoredNudge(state.nudges.contextLimitAnchors, messages, prompts.contextLimitNudge, compressedBlockGuidance);
	applyRangeModeAnchoredNudge(turnNudgeAnchors, messages, prompts.turnNudge, compressedBlockGuidance);
	applyRangeModeAnchoredNudge(state.nudges.iterationNudgeAnchors, messages, prompts.iterationNudge, compressedBlockGuidance);
}
