import { syncCompressionBlocks } from "../messages/index.js";
import { parseBlockRef } from "../message-ids.js";
import { getCurrentParams } from "../token-utils.js";
import { saveSessionState } from "../state/persistence.js";
import { sendIgnoredMessage } from "../ui/notification.js";
import { formatTokenCount } from "../ui/utils.js";
import {
	getActiveCompressionTargets,
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

function findActiveParentBlockId(messagesState, block) {
	const queue = [...block.parentBlockIds],
		visited = new Set;

	while (queue.length > 0) {
		const parentBlockId = queue.shift();

		if (parentBlockId === undefined || visited.has(parentBlockId)) {
			continue;
		}

		visited.add(parentBlockId);

		const parent = messagesState.blocksById.get(parentBlockId);

		if (!parent) {
			continue;
		}

		if (parent.active) {
			return parent.blockId;
		}

		for (const ancestorId of parent.parentBlockIds) {
			if (!visited.has(ancestorId)) {
				queue.push(ancestorId);
			}
		}
	}

	return null;
}

function findActiveAncestorBlockId(messagesState, target) {
	for (const block of target.blocks) {
		const activeAncestorBlockId = findActiveParentBlockId(messagesState, block);

		if (activeAncestorBlockId !== null) {
			return activeAncestorBlockId;
		}
	}

	return null;
}

function snapshotActiveMessages(messagesState) {
	const activeMessages = new Map;

	for (const [messageId, entry] of messagesState.byMessageId) {
		if (entry.activeBlockIds.length > 0) {
			activeMessages.set(messageId, entry.tokenCount);
		}
	}

	return activeMessages;
}

function formatDecompressMessage(target, restoredMessageCount, restoredTokens, reactivatedBlockIds) {
	const lines = [];

	lines.push(`Restored compression ${target.displayId}.`);

	if (target.runId !== target.displayId || target.grouped) {
		lines.push(`Tool call label: Compression #${target.runId}.`);
	}

	if (reactivatedBlockIds.length > 0) {
		const refs = reactivatedBlockIds.map((id) => String(id)).join(", ");

		lines.push(`Also restored nested compression(s): ${refs}.`);
	}

	if (restoredMessageCount > 0) {
		lines.push(`Restored ${restoredMessageCount} message(s) (~${formatTokenCount(restoredTokens)}).`);
	} else {
		lines.push("No messages were restored.");
	}

	return lines.join("\n");
}

function formatAvailableBlocksMessage(availableTargets) {
	const lines = [];

	lines.push("Usage: /dcp decompress <n>");
	lines.push("");

	if (availableTargets.length === 0) {
		lines.push("No compressions are available to restore.");

		return lines.join("\n");
	}

	lines.push("Available compressions:");

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

export async function handleDecompressCommand(ctx) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages, args: args } = ctx;

	const params = getCurrentParams(state, messages, logger),
		targetArg = args[0];

	if (args.length > 1) {
		await sendIgnoredMessage(client, sessionId, "Invalid arguments. Usage: /dcp decompress <n>", params, logger);

		return;
	}

	syncCompressionBlocks(state, logger, messages);

	const messagesState = state.prune.messages;

	if (!targetArg) {
		const availableTargets = getActiveCompressionTargets(messagesState),
			message = formatAvailableBlocksMessage(availableTargets);

		await sendIgnoredMessage(client, sessionId, message, params, logger);

		return;
	}

	const targetBlockId = parseBlockIdArg(targetArg);

	if (targetBlockId === null) {
		await sendIgnoredMessage(client, sessionId, `Please enter a compression number. Example: /dcp decompress 2`, params, logger);

		return;
	}

	const target = resolveCompressionTarget(messagesState, targetBlockId);

	if (!target) {
		await sendIgnoredMessage(client, sessionId, `Compression ${targetBlockId} does not exist.`, params, logger);

		return;
	}

	const activeBlocks = target.blocks.filter((block) => block.active);

	if (activeBlocks.length === 0) {
		const activeAncestorBlockId = findActiveAncestorBlockId(messagesState, target);

		if (activeAncestorBlockId !== null) {
			await sendIgnoredMessage(client, sessionId, `Compression ${target.displayId} is inside compression ${activeAncestorBlockId}. Restore compression ${activeAncestorBlockId} first.`, params, logger);

			return;
		}

		await sendIgnoredMessage(client, sessionId, `Compression ${target.displayId} is not active.`, params, logger);

		return;
	}

	const activeMessagesBefore = snapshotActiveMessages(messagesState),
		activeBlockIdsBefore = new Set(messagesState.activeBlockIds),
		deactivatedAt = Date.now();

	for (const block of target.blocks) {
		block.active = false;
		block.deactivatedByUser = true;
		block.deactivatedAt = deactivatedAt;
		block.deactivatedByBlockId = undefined;
	}

	syncCompressionBlocks(state, logger, messages);

	let restoredMessageCount = 0,
		restoredTokens = 0;

	for (const [messageId, tokenCount] of activeMessagesBefore) {
		const entry = messagesState.byMessageId.get(messageId),
			isActiveNow = entry ? entry.activeBlockIds.length > 0 : false;

		if (!isActiveNow) {
			restoredMessageCount++;
			restoredTokens += tokenCount;
		}
	}

	state.stats.totalPruneTokens = Math.max(0, state.stats.totalPruneTokens - restoredTokens);

	const reactivatedBlockIds = Array.from(messagesState.activeBlockIds).filter((blockId) => !activeBlockIdsBefore.has(blockId)).sort((a, b) => a - b);

	await saveSessionState(state, logger);

	const message = formatDecompressMessage(target, restoredMessageCount, restoredTokens, reactivatedBlockIds);

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	logger.info("Decompress command completed", {
		targetBlockId: target.displayId,
		targetRunId: target.runId,
		restoredMessageCount: restoredMessageCount,
		restoredTokens: restoredTokens,
		reactivatedBlockIds: reactivatedBlockIds
	});
}
