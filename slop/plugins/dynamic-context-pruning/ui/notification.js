import {
	formatPrunedItemsList,
	formatProgressBar,
	formatStatsHeader,
	formatTokenCount
} from "./utils.js";
import { getActiveSummaryTokenUsage } from "../state/utils.js";

export const PRUNE_REASON_LABELS = {
	completion: "Task Complete",
	noise: "Noise Removal",
	extraction: "Extraction"
};

function buildMinimalMessage(state, reason) {
	const reasonSuffix = reason ? ` — ${PRUNE_REASON_LABELS[reason]}` : "";

	return formatStatsHeader(state.stats.totalPruneTokens, state.stats.pruneTokenCounter) + reasonSuffix;
}

function buildDetailedMessage(state, reason, pruneToolIds, toolMetadata, workingDirectory) {
	let message = formatStatsHeader(state.stats.totalPruneTokens, state.stats.pruneTokenCounter);

	if (pruneToolIds.length > 0) {
		const pruneTokenCounterStr = `~${formatTokenCount(state.stats.pruneTokenCounter)}`,
			reasonLabel = reason ? ` — ${PRUNE_REASON_LABELS[reason]}` : "";

		message += `

▣ Pruning (${pruneTokenCounterStr})${reasonLabel}`;

		const itemLines = formatPrunedItemsList(pruneToolIds, toolMetadata, workingDirectory);

		message += "\n" + itemLines.join("\n");
	}

	return message.trim();
}

const TOAST_BODY_MAX_LINES = 12,
	TOAST_SUMMARY_MAX_CHARS = 600;

function truncateToastBody(body, maxLines = TOAST_BODY_MAX_LINES) {
	const lines = body.split("\n");

	if (lines.length <= maxLines) {
		return body;
	}

	const kept = lines.slice(0, maxLines - 1),
		remaining = lines.length - maxLines + 1;

	return kept.join("\n") + `
... and ${remaining} more`;
}

function truncateToastSummary(summary, maxChars = TOAST_SUMMARY_MAX_CHARS) {
	if (summary.length <= maxChars) {
		return summary;
	}

	return summary.slice(0, maxChars - 3) + "...";
}

function truncateExtractedSection(message, maxChars = TOAST_SUMMARY_MAX_CHARS) {
	const marker = `

▣ Extracted`;

	const index = message.indexOf(marker);

	if (index === -1) {
		return message;
	}

	const extracted = message.slice(index);

	if (extracted.length <= maxChars) {
		return message;
	}

	return message.slice(0, index) + truncateToastSummary(extracted, maxChars);
}

export async function sendUnifiedNotification(client, logger, config, state, sessionId, pruneToolIds, toolMetadata, reason, params, workingDirectory) {
	const hasPruned = pruneToolIds.length > 0;

	if (!hasPruned) {
		return false;
	}

	if (config.pruneNotification === "off") {
		return false;
	}

	const message = config.pruneNotification === "minimal" ? buildMinimalMessage(state, reason) : buildDetailedMessage(state, reason, pruneToolIds, toolMetadata, workingDirectory);

	if (config.pruneNotificationType === "toast") {
		let toastMessage = truncateExtractedSection(message);

		toastMessage = config.pruneNotification === "minimal" ? toastMessage : truncateToastBody(toastMessage);

		await client.tui.showToast({
			body: {
				title: "DCP: Compress Notification",
				message: toastMessage,
				variant: "info",
				duration: 5000
			}
		});

		return true;
	}

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	return true;
}

function buildCompressionSummary(entries, state) {
	if (entries.length === 1) {
		return entries[0]?.summary ?? "";
	}

	return entries.map((entry) => {
		const topic = state.prune.messages.blocksById.get(entry.blockId)?.topic ?? "(unknown topic)";

		return `### ${topic}
${entry.summary}`;
	}).join("\n\n");
}

function getCompressionLabel(entries) {
	const runId = entries[0]?.runId;

	if (runId === undefined) {
		return "Compression";
	}

	return `Compression #${runId}`;
}

function formatCompressionMetrics(removedTokens, summaryTokens) {
	const metrics = [`-${formatTokenCount(removedTokens, true)} removed`];

	if (summaryTokens > 0) {
		metrics.push(`+${formatTokenCount(summaryTokens, true)} summary`);
	}

	return metrics.join(", ");
}

export async function sendCompressNotification(client, logger, config, state, sessionId, entries, batchTopic, sessionMessageIds, params) {
	if (config.pruneNotification === "off") {
		return false;
	}

	if (entries.length === 0) {
		return false;
	}

	let message;

	const compressionLabel = getCompressionLabel(entries),
		summary = buildCompressionSummary(entries, state),
		summaryTokens = entries.reduce((total, entry) => total + entry.summaryTokens, 0),
		summaryTokensStr = formatTokenCount(summaryTokens);

	const compressedTokens = entries.reduce((total, entry) => {
		const compressionBlock = state.prune.messages.blocksById.get(entry.blockId);

		if (!compressionBlock) {
			logger.error("Compression block missing for notification", {
				compressionId: entry.blockId,
				sessionId: sessionId
			});

			return total;
		}

		return total + compressionBlock.compressedTokens;
	}, 0);

	const newlyCompressedMessageIds = [],
		newlyCompressedToolIds = [],
		seenMessageIds = new Set,
		seenToolIds = new Set;

	for (const entry of entries) {
		const compressionBlock = state.prune.messages.blocksById.get(entry.blockId);

		if (!compressionBlock) {
			continue;
		}

		for (const messageId of compressionBlock.directMessageIds) {
			if (seenMessageIds.has(messageId)) {
				continue;
			}

			seenMessageIds.add(messageId);
			newlyCompressedMessageIds.push(messageId);
		}

		for (const toolId of compressionBlock.directToolIds) {
			if (seenToolIds.has(toolId)) {
				continue;
			}

			seenToolIds.add(toolId);
			newlyCompressedToolIds.push(toolId);
		}
	}

	const topic = batchTopic ?? (entries.length === 1 ? state.prune.messages.blocksById.get(entries[0]?.blockId ?? -1)?.topic ?? "(unknown topic)" : "(unknown topic)"),
		totalActiveSummaryTkns = getActiveSummaryTokenUsage(state),
		totalGross = state.stats.totalPruneTokens + state.stats.pruneTokenCounter,
		notificationHeader = `▣ DCP | ${formatCompressionMetrics(totalGross, totalActiveSummaryTkns)}`;

	if (config.pruneNotification === "minimal") {
		message = `${notificationHeader} — ${compressionLabel}`;
	} else {
		message = notificationHeader;

		const activePrunedMessages = new Map;

		for (const [messageId, entry] of state.prune.messages.byMessageId) {
			if (entry.activeBlockIds.length > 0) {
				activePrunedMessages.set(messageId, entry.tokenCount);
			}
		}

		const progressBar = formatProgressBar(sessionMessageIds, activePrunedMessages, newlyCompressedMessageIds, 50);

		message += `

${progressBar}`;
		message += `
▣ ${compressionLabel} ${formatCompressionMetrics(compressedTokens, summaryTokens)}`;
		message += `
→ Topic: ${topic}`;
		message += `
→ Items: ${newlyCompressedMessageIds.length} messages`;

		if (newlyCompressedToolIds.length > 0) {
			message += ` and ${newlyCompressedToolIds.length} tools compressed`;
		} else {
			message += ` compressed`;
		}

		if (config.compress.showCompression) {
			message += `
→ Compression (~${summaryTokensStr}): ${summary}`;
		}
	}

	if (config.pruneNotificationType === "toast") {
		let toastMessage = message;

		if (config.compress.showCompression) {
			const truncatedSummary = truncateToastSummary(summary);

			if (truncatedSummary !== summary) {
				toastMessage = toastMessage.replace(`
→ Compression (~${summaryTokensStr}): ${summary}`, `
→ Compression (~${summaryTokensStr}): ${truncatedSummary}`);
			}
		}

		toastMessage = config.pruneNotification === "minimal" ? toastMessage : truncateToastBody(toastMessage);

		await client.tui.showToast({
			body: {
				title: "DCP: Compress Notification",
				message: toastMessage,
				variant: "info",
				duration: 5000
			}
		});

		return true;
	}

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	return true;
}

export async function sendIgnoredMessage(client, sessionID, text, params, logger) {
	const agent = params.agent || undefined,
		variant = params.variant || undefined;

	const model = params.providerId && params.modelId ? {
		providerID: params.providerId,
		modelID: params.modelId
	} : undefined;

	try {
		await client.session.prompt({
			path: {
				id: sessionID
			},
			body: {
				noReply: true,
				agent: agent,
				model: model,
				variant: variant,
				parts: [
					{
						type: "text",
						text: text,
						ignored: true
					}
				]
			}
		});
	} catch (error) {
		logger.error("Failed to send notification", { error: error.message });
	}
}
