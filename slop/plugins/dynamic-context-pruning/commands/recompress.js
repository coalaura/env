import { syncCompressionBlocks } from "../messages/index.js";
import { parseBlockRef } from "../message-ids.js";
import { getCurrentParams } from "../token-utils.js";
import { saveSessionState } from "../state/persistence.js";
import { sendIgnoredMessage } from "../ui/notification.js";
import { formatTokenCount } from "../ui/utils.js";
import {
	getRecompressibleCompressionTargets,
	resolveCompressionTarget
} from "./compression-targets.js";

function parseBlockIdArg(arg) {
	const normalized = arg.trim().toLowerCase(),
		blockRef = parseBlockRef(normalized) ?? parseBlockRef(normalized, "compact");

	if (blockRef !== null) {
		return blockRef;
	}

	if (!/^[1-9]\d*$/.test(normalized)) {
		return null;
	}

	const parsed = Number.parseInt(normalized, 10);

	return Number.isInteger(parsed) && parsed > 0 ? parsed : null;
}

function snapshotActiveMessages(messagesState) {
	const activeMessages = new Set;

	for (const [messageId, entry] of messagesState.byMessageId) {
		if (entry.activeBlockIds.length > 0) {
			activeMessages.add(messageId);
		}
	}

	return activeMessages;
}

function formatRecompressMessage(target, recompressedMessageCount, recompressedTokens, deactivatedBlockIds) {
	const lines = [];

	lines.push(`Re-applied compression ${target.displayId}.`);

	if (target.runId !== target.displayId || target.grouped) {
		lines.push(`Tool call label: Compression #${target.runId}.`);
	}

	if (deactivatedBlockIds.length > 0) {
		const refs = deactivatedBlockIds.map((id) => String(id)).join(", ");

		lines.push(`Also re-compressed nested compression(s): ${refs}.`);
	}

	if (recompressedMessageCount > 0) {
		lines.push(`Re-compressed ${recompressedMessageCount} message(s) (~${formatTokenCount(recompressedTokens)}).`);
	} else {
		lines.push("No messages were re-compressed.");
	}

	return lines.join("\n");
}

function formatAvailableBlocksMessage(availableTargets) {
	const lines = [];

	lines.push("Usage: /dcp recompress <n>");
	lines.push("");

	if (availableTargets.length === 0) {
		lines.push("No user-decompressed blocks are available to re-compress.");

		return lines.join("\n");
	}

	lines.push("Available user-decompressed compressions:");

	const entries = availableTargets.map((target) => {
		const topic = target.topic.replace(/\s+/g, " ").trim() || "(no topic)",
			label = `${target.displayId} (${formatTokenCount(target.compressedTokens)})`,
			details = target.grouped ? `Compression #${target.runId} - ${target.blocks.length} messages` : `Compression #${target.runId}`;

		return { label: label, topic: `${details} - ${topic}` };
	});

	const labelWidth = Math.max(...entries.map((entry) => entry.label.length)) + 4;

	for (const entry of entries) {
		lines.push(`  ${entry.label.padEnd(labelWidth)}${entry.topic}`);
	}

	return lines.join("\n");
}

export async function handleRecompressCommand(ctx) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages, args: args } = ctx;

	const params = getCurrentParams(state, messages, logger),
		targetArg = args[0];

	if (args.length > 1) {
		await sendIgnoredMessage(client, sessionId, "Invalid arguments. Usage: /dcp recompress <n>", params, logger);

		return;
	}

	syncCompressionBlocks(state, logger, messages);

	const messagesState = state.prune.messages,
		availableMessageIds = new Set(messages.map((msg) => msg.info.id));

	if (!targetArg) {
		const availableTargets = getRecompressibleCompressionTargets(messagesState, availableMessageIds),
			message = formatAvailableBlocksMessage(availableTargets);

		await sendIgnoredMessage(client, sessionId, message, params, logger);

		return;
	}

	const targetBlockId = parseBlockIdArg(targetArg);

	if (targetBlockId === null) {
		await sendIgnoredMessage(client, sessionId, `Please enter a compression number. Example: /dcp recompress 2`, params, logger);

		return;
	}

	const target = resolveCompressionTarget(messagesState, targetBlockId);

	if (!target) {
		await sendIgnoredMessage(client, sessionId, `Compression ${targetBlockId} does not exist.`, params, logger);

		return;
	}

	if (target.blocks.some((block) => !availableMessageIds.has(block.compressMessageId))) {
		await sendIgnoredMessage(client, sessionId, `Compression ${target.displayId} can no longer be re-applied because its origin message is no longer in this session.`, params, logger);

		return;
	}

	if (!target.blocks.some((block) => block.deactivatedByUser)) {
		const message = target.blocks.some((block) => block.active) ? `Compression ${target.displayId} is already active.` : `Compression ${target.displayId} is not user-decompressed.`;

		await sendIgnoredMessage(client, sessionId, message, params, logger);

		return;
	}

	const activeMessagesBefore = snapshotActiveMessages(messagesState),
		activeBlockIdsBefore = new Set(messagesState.activeBlockIds);

	for (const block of target.blocks) {
		block.deactivatedByUser = false;
		block.deactivatedAt = undefined;
		block.deactivatedByBlockId = undefined;
	}

	syncCompressionBlocks(state, logger, messages);

	let recompressedMessageCount = 0,
		recompressedTokens = 0;

	for (const [messageId, entry] of messagesState.byMessageId) {
		const isActiveNow = entry.activeBlockIds.length > 0;

		if (isActiveNow && !activeMessagesBefore.has(messageId)) {
			recompressedMessageCount++;
			recompressedTokens += entry.tokenCount;
		}
	}

	state.stats.totalPruneTokens += recompressedTokens;

	const deactivatedBlockIds = Array.from(activeBlockIdsBefore).filter((blockId) => !messagesState.activeBlockIds.has(blockId)).sort((a, b) => a - b);

	await saveSessionState(state, logger);

	const message = formatRecompressMessage(target, recompressedMessageCount, recompressedTokens, deactivatedBlockIds);

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	logger.info("Recompress command completed", {
		targetBlockId: target.displayId,
		targetRunId: target.runId,
		recompressedMessageCount: recompressedMessageCount,
		recompressedTokens: recompressedTokens,
		deactivatedBlockIds: deactivatedBlockIds
	});
}
