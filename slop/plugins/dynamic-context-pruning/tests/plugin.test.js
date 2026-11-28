import assert from "node:assert/strict";
import test from "node:test";
import {
	mkdirSync,
	mkdtempSync,
	rmSync,
	writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const entrypoint = new URL("../index.js", import.meta.url).href;

const configModule = new URL("../config.js", import.meta.url).href,
	stateModule = new URL("../state/index.js", import.meta.url).href,
	persistenceModule = new URL("../state/persistence.js", import.meta.url).href;

function checkPlugin(configuration, assertions, hostConfig = {}) {
	const root = mkdtempSync(join(tmpdir(), "dcp-plugin-")),
		configDirectory = join(root, "config", "opencode"),
		workspace = join(root, "workspace");

	mkdirSync(configDirectory, { recursive: true });
	mkdirSync(workspace, { recursive: true });
	writeFileSync(join(configDirectory, "dcp.jsonc"), configuration);

	try {
		// Each process isolates import-time config/storage paths from other tests and real sessions.
		const script = `
			import assert from "node:assert/strict";
			import plugin from ${JSON.stringify(entrypoint)};
			import { getConfig, mergeConfig } from ${JSON.stringify(configModule)};
			import { createSessionState } from ${JSON.stringify(stateModule)};
			import { loadSessionState, saveSessionState, saveManualModeSetting } from ${JSON.stringify(persistenceModule)};
			const context = {
				directory: process.cwd(),
				client: {
					tui: { showToast: async () => assert.fail("Unexpected configuration warning") },
					session: {
						messages: async () => ({ data: [] }),
						get: async () => ({ data: {} })
					}
				}
			};
			const config = getConfig(context);
			const hooks = await plugin(context);
			const host = ${JSON.stringify(hostConfig)};
			await hooks.config?.(host);
			${assertions}
		`;

		const result = Bun.spawnSync([process.execPath, "--eval", script], {
			cwd: workspace,
			env: {
				...process.env,
				XDG_CONFIG_HOME: join(root, "config"),
				XDG_DATA_HOME: join(root, "data"),
				OPENCODE_CONFIG_DIR: "",
				OPENCODE_SERVER_PASSWORD: ""
			},
			stdout: "pipe",
			stderr: "pipe"
		});

		assert.equal(result.exitCode, 0, result.stderr.toString());
	} finally {
		rmSync(root, { recursive: true, force: true });
	}
}

test("v1 entrypoint honors the configured range workflow and exposes JSON Schema tools", () => {
	checkPlugin(`{
		// Match the configured workflow, including JSONC trailing commas.
		"enabled": true,
		"pruneNotification": "minimal",
		"pruneNotificationType": "toast",
		"turnProtection": { "enabled": true, "turns": 2 },
		"compress": {
			"mode": "range", "permission": "allow", "showCompression": true,
			"summaryBuffer": true, "minContextLimit": 50000, "maxContextLimit": 85000,
			"nudgeFrequency": 5, "iterationNudgeThreshold": 12,
			"nudgeForce": "soft", "protectUserMessages": true,
		},
		"strategies": { "deduplication": { "enabled": true }, "purgeErrors": { "enabled": true, "turns": 3 } },
		"experimental": { "allowSubAgents": false, "customPrompts": false },
	}`, `
		assert.equal(config.compress.mode, "range");
		assert.equal(config.compress.minContextLimit, 50000);
		assert.equal(config.compress.maxContextLimit, 85000);
		assert.equal(config.compress.iterationNudgeThreshold, 12);
		assert.equal(config.compress.nudgeFrequency, 5);
		assert.equal(config.compress.nudgeForce, "soft");
		assert.equal(config.compress.showCompression, true);
		assert.equal(config.compress.summaryBuffer, true);
		assert.equal(config.compress.protectUserMessages, true);
		assert.deepEqual(config.compress.protectedTools, ["task", "skill", "todowrite", "todoread"]);
		assert.deepEqual(config.turnProtection, { enabled: true, turns: 2 });
		assert.equal(config.pruneNotification, "minimal");
		assert.equal(config.pruneNotificationType, "toast");
		assert.equal(config.strategies.deduplication.enabled, true);
		assert.equal(config.strategies.purgeErrors.turns, 3);
		assert.deepEqual(host.experimental.primary_tools, ["existing", "compress"]);
		assert.equal(host.permission.compress, "allow");
		assert.equal(host.command.dcp, undefined);
		assert.ok(host.command["dcp-compress"]);
		assert.equal(host.command.existing.template, "preserve me");
		await hooks.config(host);
		assert.deepEqual(host.experimental.primary_tools, ["existing", "compress"]);
		const tool = hooks.tool.compress;
		assert.equal(tool.args.topic.type, "string");
		assert.equal(tool.args.content.type, "array");
		assert.deepEqual(tool.args.content.items.required, ["startId", "endId", "summary"]);
		assert.match(tool.description, /COMPRESSED BLOCK PLACEHOLDERS/);
		assert.ok(!JSON.stringify(tool.args).includes("_zod"));
		await assert.rejects(tool.execute({ topic: "Check", content: [] }, { sessionID: "test" }), /non-empty array/);
		const output = { system: ["Base system prompt"] };
		await hooks["experimental.chat.system.transform"]({ sessionID: "test", model: { limit: { context: 200000 } } }, output);
		assert.match(output.system[0], /^Base system prompt/);
		assert.match(output.system[0], /<dcp-system-reminder>/);
		assert.match(output.system[0], /task.*skill.*todowrite.*todoread/s);
	`, {
		experimental: { primary_tools: ["existing"] },
		command: { existing: { template: "preserve me" } }
	});
});

test("disabled plugin returns no hooks", () => {
	checkPlugin('{"enabled": false}', "assert.deepEqual(hooks, {});");
});

test("denied compression does not register a tool or inject a system prompt", () => {
	checkPlugin('{"compress": {"permission": "deny"}}', `
		assert.deepEqual(hooks.tool, {});
		assert.equal(host.command, undefined);
		const output = { system: ["Base"] };
		await hooks["experimental.chat.system.transform"]({}, output);
		assert.deepEqual(output.system, ["Base"]);
	`);
});

test("host denial overrides the plugin permission", () => {
	checkPlugin('{}', `
		assert.equal(host.permission.compress, "deny");
		assert.equal(host.command, undefined);
		assert.equal(host.experimental, undefined);
		const output = { system: ["Base"] };
		await hooks["experimental.chat.system.transform"]({}, output);
		assert.deepEqual(output.system, ["Base"]);
	`, { permission: { compress: "deny" } });
});

test("message mode and subagent opt-in retain the alternate tool contract", () => {
	checkPlugin('{"compress": {"mode": "message"}, "experimental": {"allowSubAgents": true}}', `
		assert.equal(host.experimental, undefined);
		assert.deepEqual(hooks.tool.compress.args.content.items.required, ["messageId", "topic", "summary"]);
		assert.match(hooks.tool.compress.description, /selected individual messages/i);
	`);
});

test("concurrent sessions isolate compression, references, timing events, and resumed state", () => {
	checkPlugin('{"pruneNotification": "off"}', `
		function messagesFor(sessionID) {
			return ["user", "assistant", "user"].map((role, index) => ({
				info: {
					id: \`\${sessionID}-\${index}\`,
					role: role,
					sessionID: sessionID,
					agent: "build",
					model: { providerID: "test", modelID: "test" },
					time: { created: index + 1 }
				},
				parts: [{ type: "text", text: \`\${sessionID} message \${index}\` }]
			}));
		}

		const histories = { alpha: messagesFor("alpha"), beta: messagesFor("beta") };
		const initialization = Promise.withResolvers();
		const entered = Promise.withResolvers();
		let alphaLoads = 0;
		context.client.session.messages = async ({ path }) => ({ data: structuredClone(histories[path.id]) });
		context.client.session.get = async ({ path }) => {
			if (path.id === "alpha") {
				alphaLoads++;
				if (alphaLoads === 1) {
					entered.resolve();
					await initialization.promise;
				}
			}
			return { data: {} };
		};

		const alphaOutput = { messages: structuredClone(histories.alpha) };
		const betaOutput = { messages: structuredClone(histories.beta) };
		await timing("alpha", "pending", 1000);
		const alphaTransform = hooks["experimental.chat.messages.transform"]({}, alphaOutput);
		await entered.promise;
		const alphaSystem = { system: ["Base"] };
		const queuedSystem = hooks["experimental.chat.system.transform"]({ sessionID: "alpha", model: { limit: { context: 200000 } } }, alphaSystem);
		await hooks["experimental.chat.messages.transform"]({}, betaOutput);
		assert.equal(alphaLoads, 1);
		assert.match(betaOutput.messages[0].parts[0].text, /m0001/);
		initialization.resolve();
		await Promise.all([alphaTransform, queuedSystem]);
		assert.match(alphaOutput.messages[0].parts[0].text, /m0001/);
		assert.match(alphaSystem.system[0], /<dcp-system-reminder>/);

		const anonymous = { system: ["Base"] };
		await hooks["experimental.chat.system.transform"]({}, anonymous);
		assert.deepEqual(anonymous.system, ["Base"]);
		await assert.rejects(hooks["experimental.chat.messages.transform"]({}, { messages: [...histories.alpha, ...histories.beta] }), /multiple sessions/);

		async function timing(sessionID, status, time) {
			await hooks.event({ event: {
				type: "message.part.updated",
				time: time,
				properties: { part: {
					type: "tool", tool: "compress", sessionID: sessionID,
					messageID: "same-tool-message", callID: "same-call", state: { status: status }
				} }
			} });
		}

		const permission = Promise.withResolvers();
		const asked = Promise.withResolvers();
		function compress(sessionID) {
			return hooks.tool.compress.execute({
				topic: sessionID,
				content: [{ startId: "m0001", endId: "m0002", summary: \`\${sessionID} summary\` }]
			}, {
				sessionID: sessionID,
				messageID: "same-tool-message",
				callID: "same-call",
				metadata() {},
				async ask() {
					if (sessionID === "alpha") {
						asked.resolve();
						await permission.promise;
					}
				}
			});
		}

		const alphaCompress = compress("alpha");
		await asked.promise;
		await timing("alpha", "pending", 1000);
		await timing("beta", "pending", 2000);
		await compress("beta");
		await timing("beta", "completed", 2300);
		permission.resolve();
		await alphaCompress;
		await timing("alpha", "completed", 1900);

		const logger = { info() {}, warn() {}, error(message) { assert.fail(message); } };
		const alphaState = await loadSessionState("alpha", logger);
		const betaState = await loadSessionState("beta", logger);
		const alphaBlock = Object.values(alphaState.prune.messages.blocksById)[0];
		const betaBlock = Object.values(betaState.prune.messages.blocksById)[0];
		assert.equal(Object.keys(alphaState.prune.messages.blocksById).length, 1);
		assert.equal(Object.keys(betaState.prune.messages.blocksById).length, 1);
		assert.equal(alphaBlock.durationMs, 900);
		assert.equal(betaBlock.durationMs, 300);
		assert.match(JSON.stringify(alphaBlock), /alpha summary/);
		assert.doesNotMatch(JSON.stringify(alphaBlock), /beta/);
		assert.match(JSON.stringify(betaBlock), /beta summary/);
		assert.doesNotMatch(JSON.stringify(betaBlock), /alpha/);

		await hooks.event({ event: { type: "session.deleted", properties: { info: { id: "alpha" } } } });
		await hooks["experimental.chat.system.transform"]({ sessionID: "alpha", model: { limit: { context: 200000 } } }, { system: ["Base"] });
		assert.equal(alphaLoads, 2);
		assert.deepEqual((await loadSessionState("alpha", logger)).prune, alphaState.prune);
	`);
});

test("persistence serializes snapshots and manual-mode updates without torn reads", () => {
	checkPlugin('{}', `
		const logger = { info() {}, warn() {}, error(message) { assert.fail(message); } };
		const state = createSessionState();
		state.sessionId = "snapshots";
		const writes = [];
		for (let index = 0; index < 30; index++) {
			state.stats.totalPruneTokens = index;
			writes.push(saveSessionState(state, logger));
		}
		state.stats.totalPruneTokens = 999;
		const manual = saveManualModeSetting("snapshots", true, logger);
		const loaded = await loadSessionState("snapshots", logger);
		await Promise.all([...writes, manual]);
		assert.equal(loaded.stats.totalPruneTokens, 29);
		assert.equal(loaded.manualMode, true);
		assert.deepEqual(loaded.prune.tools, {});
	`);
});

test("defaults match the personal workflow and invalid overrides leave usable settings", () => {
	checkPlugin('{}', `
		assert.equal(config.pruneNotification, "minimal");
		assert.equal(config.pruneNotificationType, "toast");
		assert.deepEqual(config.turnProtection, { enabled: true, turns: 2 });
		assert.equal(config.compress.maxContextLimit, 85000);
		assert.equal(config.compress.minContextLimit, 50000);
		assert.equal(config.compress.iterationNudgeThreshold, 12);
		assert.equal(config.compress.protectUserMessages, true);
		assert.equal(config.compress.showCompression, true);
		assert.equal(config.strategies.purgeErrors.turns, 3);
		const warnings = [];
		mergeConfig(config, {
			compress: { mode: "unknown", protectedTools: [42], maxContextLimit: "bad", modelMinLimits: [] },
			strategies: false,
			unknown: true
		}, warnings);
		assert.equal(warnings.length, 6);
		assert.equal(config.compress.mode, "range");
		assert.equal(config.compress.maxContextLimit, 85000);
		assert.deepEqual(config.compress.protectedTools, ["task", "skill", "todowrite", "todoread"]);
		assert.equal(config.strategies.purgeErrors.turns, 3);
	`);
});

test("config layers preserve JSONC priority, protected-list unions, and replacement model maps", () => {
	checkPlugin('{"turnProtection": {"turns": 2}}', `
		const { mkdirSync, writeFileSync } = await import("node:fs");
		const { join } = await import("node:path");
		const extra = join(process.cwd(), "extra");
		const project = join(process.cwd(), ".opencode");
		mkdirSync(extra);
		mkdirSync(project);
		process.env.OPENCODE_CONFIG_DIR = extra;
		writeFileSync(join(process.env.XDG_CONFIG_HOME, "opencode", "dcp.json"), '{"turnProtection": {"turns": 99}}');
		writeFileSync(join(extra, "dcp.jsonc"), JSON.stringify({
			compress: { protectedTools: ["extra"], modelMaxLimits: { first: 90000 } },
			protectedFilePatterns: ["*.secret"]
		}));
		writeFileSync(join(project, "dcp.json"), JSON.stringify({
			compress: { protectedTools: ["project", "extra"], modelMaxLimits: { second: "80%" }, minContextLimit: "25%" },
			protectedFilePatterns: ["*.private", "*.secret"]
		}));
		const layered = getConfig(context);
		assert.equal(layered.turnProtection.turns, 2);
		assert.deepEqual(layered.compress.protectedTools, ["task", "skill", "todowrite", "todoread", "extra", "project"]);
		assert.deepEqual(layered.compress.modelMaxLimits, { second: "80%" });
		assert.equal(layered.compress.minContextLimit, "25%");
		assert.deepEqual(layered.protectedFilePatterns, ["*.secret", "*.private"]);
	`);
});
