import { sendIgnoredMessage } from "../ui/notification.js";
import { formatTokenCount } from "../ui/utils.js";
import { loadAllSessionStats } from "../state/persistence.js";
import { getCurrentParams } from "../token-utils.js";
import { getActiveCompressionTargets } from "./compression-targets.js";

export function formatStatsMessage(sessionTokens, sessionSummaryTokens, sessionTools, sessionMessages, sessionDurationMs, allTime) {
	const lines = [];

	lines.push("╭───────────────────────────────────────────────────────────╮");
	lines.push("│                    DCP Statistics                         │");
	lines.push("╰───────────────────────────────────────────────────────────╯");
	lines.push("");
	lines.push("Compression:");
	lines.push("─".repeat(60));
	lines.push(`  Tokens in|out:    ~${formatTokenCount(sessionTokens)} | ~${formatTokenCount(sessionSummaryTokens)}`);
	lines.push(`  Ratio:            ${formatCompressionRatio(sessionTokens, sessionSummaryTokens)}`);
	lines.push(`  Time:             ${formatCompressionTime(sessionDurationMs)}`);
	lines.push(`  Messages:         ${sessionMessages}`);
	lines.push(`  Tools:            ${sessionTools}`);
	lines.push("");
	lines.push("All-time:");
	lines.push("─".repeat(60));
	lines.push(`  Tokens saved:    ~${formatTokenCount(allTime.totalTokens)}`);
	lines.push(`  Tools pruned:     ${allTime.totalTools}`);
	lines.push(`  Messages pruned:  ${allTime.totalMessages}`);
	lines.push(`  Sessions:         ${allTime.sessionCount}`);

	return lines.join("\n");
}

function formatCompressionRatio(inputTokens, outputTokens) {
	if (inputTokens <= 0) {
		return "0:1";
	}

	if (outputTokens <= 0) {
		return "∞:1";
	}

	const ratio = Math.max(1, Math.round(inputTokens / outputTokens));

	return `${ratio}:1`;
}

function formatCompressionTime(ms) {
	const safeMs = Math.max(0, Math.round(ms));

	if (safeMs < 1000) {
		return `${safeMs} ms`;
	}

	const totalSeconds = safeMs / 1000;

	if (totalSeconds < 60) {
		return `${totalSeconds.toFixed(1)} s`;
	}

	const wholeSeconds = Math.floor(totalSeconds),
		hours = Math.floor(wholeSeconds / 3600),
		minutes = Math.floor(wholeSeconds % 3600 / 60),
		seconds = wholeSeconds % 60;

	if (hours > 0) {
		return `${hours}h ${minutes}m ${seconds}s`;
	}

	return `${minutes}m ${seconds}s`;
}

export async function handleStatsCommand(ctx) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages } = ctx;

	const report = await buildStatsReport(state, logger),
		message = formatStatsMessage(report.sessionTokens, report.sessionSummaryTokens, report.sessionTools, report.sessionMessages, report.sessionDurationMs, report.allTime),
		params = getCurrentParams(state, messages, logger);

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	logger.info("Stats command executed", {
		sessionTokens: report.sessionTokens,
		sessionSummaryTokens: report.sessionSummaryTokens,
		sessionTools: report.sessionTools,
		sessionMessages: report.sessionMessages,
		sessionDurationMs: report.sessionDurationMs,
		allTimeTokens: report.allTime.totalTokens,
		allTimeTools: report.allTime.totalTools,
		allTimeMessages: report.allTime.totalMessages
	});
}

export async function buildStatsReport(state, logger) {
	const sessionTokens = state.stats.totalPruneTokens,
		sessionSummaryTokens = Array.from(state.prune.messages.blocksById.values()).reduce((total, block) => block.active ? total + block.summaryTokens : total, 0),
		sessionDurationMs = getActiveCompressionTargets(state.prune.messages).reduce((total, target) => total + target.durationMs, 0),
		prunedToolIds = new Set(state.prune.tools.keys());

	for (const block of state.prune.messages.blocksById.values()) {
		if (block.active) {
			for (const toolId of block.effectiveToolIds) {
				prunedToolIds.add(toolId);
			}
		}
	}

	const sessionTools = prunedToolIds.size;

	let sessionMessages = 0;

	for (const entry of state.prune.messages.byMessageId.values()) {
		if (entry.activeBlockIds.length > 0) {
			sessionMessages++;
		}
	}

	const allTime = await loadAllSessionStats(logger);

	return {
		sessionTokens: sessionTokens,
		sessionSummaryTokens: sessionSummaryTokens,
		sessionTools: sessionTools,
		sessionMessages: sessionMessages,
		sessionDurationMs: sessionDurationMs,
		allTime: allTime
	};
}
