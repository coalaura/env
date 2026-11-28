import assert from "node:assert/strict";
import test from "node:test";
import { getActiveCompressionTargets } from "../commands/compression-targets.js";
import { createSessionState } from "../state/index.js";

function buildBlock(blockId, runId, mode, durationMs) {
	return {
		blockId: blockId,
		runId: runId,
		active: true,
		deactivatedByUser: false,
		compressedTokens: 10,
		summaryTokens: 5,
		durationMs: durationMs,
		mode: mode,
		topic: `topic-${blockId}`,
		batchTopic: mode === "message" ? `batch-${runId}` : `topic-${blockId}`,
		startId: `m${blockId}`,
		endId: `m${blockId}`,
		anchorMessageId: `msg-${blockId}`,
		compressMessageId: `origin-${runId}`,
		includedBlockIds: [],
		consumedBlockIds: [],
		parentBlockIds: [],
		directMessageIds: [`msg-${blockId}`],
		directToolIds: [],
		effectiveMessageIds: [`msg-${blockId}`],
		effectiveToolIds: [],
		createdAt: blockId,
		summary: `summary-${blockId}`
	};
}

test("active compression targets count a grouped message run once", () => {
	const state = createSessionState(),
		first = buildBlock(1, 10, "message", 225),
		second = buildBlock(2, 10, "message", 225),
		third = buildBlock(3, 11, "range", 80);

	state.prune.messages.blocksById.set(1, first);
	state.prune.messages.blocksById.set(2, second);
	state.prune.messages.blocksById.set(3, third);
	state.prune.messages.activeBlockIds.add(1);
	state.prune.messages.activeBlockIds.add(2);
	state.prune.messages.activeBlockIds.add(3);

	const targets = getActiveCompressionTargets(state.prune.messages),
		totalDurationMs = targets.reduce((total, target) => total + target.durationMs, 0);

	assert.equal(targets.length, 2);
	assert.equal(totalDurationMs, 305);
});

test("inactive grouped message runs no longer contribute compression time", () => {
	const state = createSessionState(),
		first = buildBlock(1, 10, "message", 225),
		second = buildBlock(2, 10, "message", 225),
		third = buildBlock(3, 11, "range", 80);

	first.active = false;
	second.active = false;

	state.prune.messages.blocksById.set(1, first);
	state.prune.messages.blocksById.set(2, second);
	state.prune.messages.blocksById.set(3, third);
	state.prune.messages.activeBlockIds.add(3);

	const targets = getActiveCompressionTargets(state.prune.messages),
		totalDurationMs = targets.reduce((total, target) => total + target.durationMs, 0);

	assert.equal(targets.length, 1);
	assert.equal(totalDurationMs, 80);
});
