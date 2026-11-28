import assert from "node:assert/strict";
import test from "node:test";
import { finalizeSession } from "../compress/pipeline.js";
import { Logger } from "../logger.js";
import {
	createSessionState,
	loadManualModeSetting,
	saveManualModeSetting
} from "../state/index.js";

function buildConfig(manualMode = false) {
	return {
		enabled: true,
		debug: false,
		pruneNotification: "off",
		pruneNotificationType: "chat",
		commands: { enabled: true, protectedTools: [] },
		manualMode: { enabled: manualMode, automaticStrategies: true },
		turnProtection: { enabled: false, turns: 4 },
		experimental: { allowSubAgents: false, customPrompts: false },
		protectedFilePatterns: [],
		compress: {
			mode: "message",
			permission: "allow",
			showCompression: false,
			maxContextLimit: 150000,
			minContextLimit: 50000,
			nudgeFrequency: 5,
			iterationNudgeThreshold: 15,
			nudgeForce: "soft",
			protectedTools: ["task"],
			protectTags: false,
			protectUserMessages: false
		},
		strategies: {
			deduplication: { enabled: true, protectedTools: [] },
			purgeErrors: { enabled: true, turns: 4, protectedTools: [] }
		}
	};
}

function buildToolContext(state, manualMode = false) {
	return {
		client: { session: { get: async () => ({}) } },
		state: state,
		logger: new Logger(false),
		config: buildConfig(manualMode),
		prompts: {
			reload() {},
			getRuntimePrompts() {
				return {};
			}
		}
	};
}

test("finalizeSession resets compress-pending to auto mode", async () => {
	const sessionId = `finalize-compress-pending-${Date.now()}`,
		state = createSessionState();

	state.sessionId = sessionId;
	state.manualMode = "compress-pending";

	await finalizeSession(buildToolContext(state), { sessionID: sessionId, metadata: () => {}, ask: async () => {} }, [], [], undefined);
	assert.equal(state.manualMode, false);

	const persisted = await loadManualModeSetting(sessionId, new Logger(false));

	assert.equal(persisted, false);
});

test("finalizeSession restores persisted manual mode after compression", async () => {
	const sessionId = `finalize-persisted-manual-${Date.now()}`,
		logger = new Logger(false);

	await saveManualModeSetting(sessionId, true, logger);

	const state = createSessionState();

	state.sessionId = sessionId;
	state.manualMode = "compress-pending";

	await finalizeSession(buildToolContext(state), { sessionID: sessionId, metadata: () => {}, ask: async () => {} }, [], [], undefined);
	assert.equal(state.manualMode, "active");

	const persisted = await loadManualModeSetting(sessionId, logger);

	assert.equal(persisted, true);
});

test("finalizeSession restores configured manual mode after compression", async () => {
	const sessionId = `finalize-configured-manual-${Date.now()}`,
		state = createSessionState();

	state.sessionId = sessionId;
	state.manualMode = "compress-pending";

	await finalizeSession(buildToolContext(state, true), { sessionID: sessionId, metadata: () => {}, ask: async () => {} }, [], [], undefined);
	assert.equal(state.manualMode, "active");

	const persisted = await loadManualModeSetting(sessionId, new Logger(false));

	assert.equal(persisted, true);
});
