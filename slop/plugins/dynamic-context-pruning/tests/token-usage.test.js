import assert from "node:assert/strict";
import test from "node:test";
import { isContextOverLimits } from "../messages/inject/utils.js";
import { wrapCompressedSummary } from "../compress/state.js";
import { createSessionState } from "../state/index.js";
import { getCurrentTokenUsage } from "../token-utils.js";

function buildConfig(maxContextLimit, minContextLimit = 1) {
	return {
		enabled: true,
		debug: false,
		pruneNotification: "off",
		pruneNotificationType: "chat",
		commands: {
			enabled: true,
			protectedTools: []
		},
		manualMode: {
			enabled: false,
			automaticStrategies: true
		},
		turnProtection: {
			enabled: false,
			turns: 4
		},
		experimental: {
			allowSubAgents: false,
			customPrompts: false
		},
		protectedFilePatterns: [],
		compress: {
			mode: "message",
			permission: "allow",
			showCompression: false,
			summaryBuffer: true,
			maxContextLimit: maxContextLimit,
			minContextLimit: minContextLimit,
			nudgeFrequency: 5,
			iterationNudgeThreshold: 15,
			nudgeForce: "soft",
			protectedTools: ["task"],
			protectTags: false,
			protectUserMessages: false
		},
		strategies: {
			deduplication: {
				enabled: true,
				protectedTools: []
			},
			purgeErrors: {
				enabled: true,
				turns: 4,
				protectedTools: []
			}
		}
	};
}

function textPart(messageID, sessionID, id, text) {
	return {
		id: id,
		messageID: messageID,
		sessionID: sessionID,
		type: "text",
		text: text
	};
}

function repeatedWord(word, count) {
	return Array.from({ length: count }, () => word).join(" ");
}

function buildCompactedMessages() {
	const sessionID = "ses_compaction_token_usage";

	return [
		{
			info: {
				id: "msg-user-summary",
				role: "user",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 1 }
			},
			parts: [
				textPart("msg-user-summary", sessionID, "msg-user-summary-part", `[Compressed conversation section]
${repeatedWord("summary", 120)}`)
			]
		},
		{
			info: {
				id: "msg-assistant-summary",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				summary: true,
				time: { created: 2 },
				tokens: {
					input: 86000,
					output: 1200,
					reasoning: 300,
					cache: {
						read: 5000,
						write: 0
					}
				}
			},
			parts: [
				textPart("msg-assistant-summary", sessionID, "msg-assistant-summary-part", `Compaction summary. ${repeatedWord("carry", 180)}`)
			]
		},
		{
			info: {
				id: "msg-user-follow-up",
				role: "user",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 3 }
			},
			parts: [
				textPart("msg-user-follow-up", sessionID, "msg-user-follow-up-part", `Continue from here. ${repeatedWord("next", 40)}`)
			]
		}
	];
}

function buildPostCompactionAssistantMessage() {
	const sessionID = "ses_compaction_token_usage";

	return {
		info: {
			id: "msg-assistant-post-compaction",
			role: "assistant",
			sessionID: sessionID,
			agent: "assistant",
			time: { created: 4 },
			tokens: {
				input: 2400,
				output: 600,
				reasoning: 150,
				cache: {
					read: 300,
					write: 0
				}
			}
		},
		parts: [
			textPart("msg-assistant-post-compaction", sessionID, "msg-assistant-post-compaction-part", `Fresh post-compaction reply. ${repeatedWord("done", 60)}`)
		]
	};
}

function createActiveBlock(blockId, summary, summaryTokens) {
	return {
		blockId: blockId,
		runId: blockId,
		active: true,
		deactivatedByUser: false,
		compressedTokens: 0,
		summaryTokens: summaryTokens,
		mode: "message",
		topic: `Summary ${blockId}`,
		batchTopic: `Summary ${blockId}`,
		startId: "m0001",
		endId: "m0001",
		anchorMessageId: `msg-${blockId}`,
		compressMessageId: `compress-${blockId}`,
		includedBlockIds: [],
		consumedBlockIds: [],
		parentBlockIds: [],
		directMessageIds: [],
		directToolIds: [],
		effectiveMessageIds: [],
		effectiveToolIds: [],
		createdAt: blockId,
		summary: summary
	};
}

test("getCurrentTokenUsage returns 0 until a fresh assistant follows compaction", () => {
	const messages = buildCompactedMessages(),
		state = createSessionState();

	state.lastCompaction = 2;

	assert.equal(getCurrentTokenUsage(state, messages), 0);
});

test("isContextOverLimits ignores stale summary totals and resumes with fresh reported totals", () => {
	const messages = buildCompactedMessages(),
		state = createSessionState();

	state.lastCompaction = 2;

	const staleAssistantTotal = 86000 + 1200 + 300 + 5000;

	assert.equal(getCurrentTokenUsage(state, messages), 0);

	const underLimit = isContextOverLimits(buildConfig(staleAssistantTotal - 1, 1), state, undefined, undefined, messages);

	assert.equal(underLimit.overMaxLimit, false);
	assert.equal(underLimit.overMinLimit, false);
	messages.push(buildPostCompactionAssistantMessage());

	const freshReportedTotal = 2400 + 600 + 150 + 300;

	assert.equal(getCurrentTokenUsage(state, messages), freshReportedTotal);

	const overLimit = isContextOverLimits(buildConfig(freshReportedTotal - 1, 1), state, undefined, undefined, messages);

	assert.equal(overLimit.overMaxLimit, true);
});

test("isContextOverLimits extends the max threshold by active summary tokens", () => {
	const messages = buildCompactedMessages();

	messages.push(buildPostCompactionAssistantMessage());

	const state = createSessionState();

	state.lastCompaction = 2;

	const storedSummary = wrapCompressedSummary(7, repeatedWord("summary", 120));

	state.prune.messages.blocksById.set(7, createActiveBlock(7, storedSummary, 1000));
	state.prune.messages.activeBlockIds.add(7);

	const freshReportedTotal = 2400 + 600 + 150 + 300,
		underExtendedLimit = isContextOverLimits(buildConfig(freshReportedTotal - 1, 1), state, undefined, undefined, messages);

	assert.equal(underExtendedLimit.overMaxLimit, false);

	const overExtendedLimit = isContextOverLimits(buildConfig(freshReportedTotal - 1001, 1), state, undefined, undefined, messages);

	assert.equal(overExtendedLimit.overMaxLimit, true);
});

test("isContextOverLimits does not extend the max threshold when summaryBuffer is disabled", () => {
	const messages = buildCompactedMessages();

	messages.push(buildPostCompactionAssistantMessage());

	const state = createSessionState();

	state.lastCompaction = 2;

	const storedSummary = wrapCompressedSummary(7, repeatedWord("summary", 120));

	state.prune.messages.blocksById.set(7, createActiveBlock(7, storedSummary, 1000));
	state.prune.messages.activeBlockIds.add(7);

	const freshReportedTotal = 2400 + 600 + 150 + 300,
		config = buildConfig(freshReportedTotal - 1, 1);

	config.compress.summaryBuffer = false;

	const overLimit = isContextOverLimits(config, state, undefined, undefined, messages);

	assert.equal(overLimit.overMaxLimit, true);
});
