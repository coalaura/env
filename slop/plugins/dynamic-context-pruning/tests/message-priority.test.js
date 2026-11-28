import assert from "node:assert/strict";
import test from "node:test";
import { createTextCompleteHandler } from "../hooks.js";
import { Logger } from "../logger.js";
import { assignMessageRefs } from "../message-ids.js";
import { injectMessageIds } from "../messages/inject/inject.js";
import { applyAnchoredNudges } from "../messages/inject/utils.js";
import { prune } from "../messages/prune.js";
import { buildPriorityMap } from "../messages/priority.js";
import { stripHallucinations, stripHallucinationsFromString } from "../messages/utils.js";
import { createSessionState } from "../state/index.js";

function buildConfig(mode = "message") {
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
			mode: mode,
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

function toolPart(messageID, sessionID, callID, toolName, output) {
	return {
		id: `${callID}-part`,
		messageID: messageID,
		sessionID: sessionID,
		type: "tool",
		tool: toolName,
		callID: callID,
		state: {
			status: "completed",
			input: { description: "demo" },
			output: output
		}
	};
}

function buildMessage(id, role, sessionID, text, created) {
	const info = role === "user" ? {
		id: id,
		role: role,
		sessionID: sessionID,
		agent: "assistant",
		model: {
			providerID: "anthropic",
			modelID: "claude-test"
		},
		time: { created: created }
	} : {
		id: id,
		role: role,
		sessionID: sessionID,
		agent: "assistant",
		time: { created: created }
	};

	return {
		info: info,
		parts: [textPart(id, sessionID, `${id}-part`, text)]
	};
}

function repeatedWord(word, count) {
	return Array.from({ length: count }, () => word).join(" ");
}

test("injectMessageIds injects ID into every tool output for assistant messages", () => {
	const sessionID = "ses_message_priority_tags";

	const messages = [
		{
			info: {
				id: "msg-user-1",
				role: "user",
				sessionID: sessionID,
				agent: "assistant",
				model: {
					providerID: "anthropic",
					modelID: "claude-test"
				},
				time: { created: 1 }
			},
			parts: [
				textPart("msg-user-1", sessionID, "msg-user-1-part-1", repeatedWord("investigate", 6000)),
				textPart("msg-user-1", sessionID, "msg-user-1-part-2", "Trailing note.")
			]
		},
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part-1", "Short follow-up note."),
				toolPart("msg-assistant-1", sessionID, "call-task-1", "task", "task output body"),
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part-2", "Second text chunk."),
				toolPart("msg-assistant-1", sessionID, "call-task-2", "bash", "second tool output body")
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig();

	assignMessageRefs(state, messages);

	const compressionPriorities = buildPriorityMap(config, state, messages);

	injectMessageIds(state, config, messages, compressionPriorities);
	assert.equal(messages[0]?.parts.length, 2);
	assert.equal(messages[1]?.parts.length, 4);

	const userTextOne = messages[0]?.parts[0],
		userTextTwo = messages[0]?.parts[1],
		assistantTextOne = messages[1]?.parts[0],
		assistantToolOne = messages[1]?.parts[1],
		assistantTextTwo = messages[1]?.parts[2],
		assistantToolTwo = messages[1]?.parts[3];

	assert.equal(userTextOne?.type, "text");
	assert.equal(userTextTwo?.type, "text");
	assert.equal(assistantTextOne?.type, "text");
	assert.equal(assistantToolOne?.type, "tool");
	assert.equal(assistantTextTwo?.type, "text");
	assert.equal(assistantToolTwo?.type, "tool");
	assert.match(userTextOne.text, /\n\n<dcp-message-id priority="high">m0001<\/dcp-message-id>/);
	assert.match(userTextTwo.text, /\n\n<dcp-message-id priority="high">m0001<\/dcp-message-id>/);
	assert.doesNotMatch(assistantTextOne.text, /dcp-message-id/);
	assert.match(assistantToolOne.state.output, /m0002<\/dcp-message-id>/);
	assert.doesNotMatch(assistantTextTwo.text, /dcp-message-id/);
	assert.match(assistantToolTwo.state.output, /m0002<\/dcp-message-id>/);
});

test("injectMessageIds marks every protected user text part as BLOCKED in message mode", () => {
	const sessionID = "ses_message_blocked_user_tags";

	const messages = [
		{
			info: {
				id: "msg-user-1",
				role: "user",
				sessionID: sessionID,
				agent: "assistant",
				model: {
					providerID: "anthropic",
					modelID: "claude-test"
				},
				time: { created: 1 }
			},
			parts: [
				textPart("msg-user-1", sessionID, "msg-user-1-part-1", repeatedWord("investigate", 6000)),
				textPart("msg-user-1", sessionID, "msg-user-1-part-2", "Trailing note.")
			]
		},
		buildMessage("msg-assistant-1", "assistant", sessionID, "Short follow-up note.", 2)
	];

	const state = createSessionState(),
		config = buildConfig();

	config.compress.protectUserMessages = true;

	assignMessageRefs(state, messages);

	const compressionPriorities = buildPriorityMap(config, state, messages);

	injectMessageIds(state, config, messages, compressionPriorities);

	const userTextOne = messages[0]?.parts[0],
		userTextTwo = messages[0]?.parts[1],
		assistantText = messages[1]?.parts[0];

	assert.equal(userTextOne?.type, "text");
	assert.equal(userTextTwo?.type, "text");
	assert.equal(assistantText?.type, "text");
	assert.match(userTextOne.text, /\n\n<dcp-message-id>BLOCKED<\/dcp-message-id>/);
	assert.match(userTextTwo.text, /\n\n<dcp-message-id>BLOCKED<\/dcp-message-id>/);
	assert.doesNotMatch(userTextOne.text, /priority=/);
	assert.doesNotMatch(userTextTwo.text, /priority=/);
	assert.match(assistantText.text, /\n\n<dcp-message-id priority="low">m0002<\/dcp-message-id>/);
});

test("injectMessageIds injects ID into every tool output in range mode", () => {
	const sessionID = "ses_range_message_id_tags";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, repeatedWord("investigate", 6000), 1),
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part-1", "First chunk."),
				toolPart("msg-assistant-1", sessionID, "call-task-range-1", "task", "first output"),
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part-2", "Second chunk."),
				toolPart("msg-assistant-1", sessionID, "call-task-range-2", "bash", "second output")
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	injectMessageIds(state, config, messages);

	const assistantTextOne = messages[1]?.parts[0],
		assistantToolOne = messages[1]?.parts[1],
		assistantTextTwo = messages[1]?.parts[2],
		assistantToolTwo = messages[1]?.parts[3];

	assert.doesNotMatch(assistantTextOne.text, /dcp-message-id/);
	assert.match(assistantToolOne.state.output, /m0002<\/dcp-message-id>/);
	assert.doesNotMatch(assistantTextTwo.text, /dcp-message-id/);
	assert.match(assistantToolTwo.state.output, /m0002<\/dcp-message-id>/);
});

test("message mode marks compress tool messages as high priority even when short", () => {
	const sessionID = "ses_message_compress_high_priority";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Please compress this chunk.", 1),
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part-1", "Done."),
				toolPart("msg-assistant-1", sessionID, "call-compress-1", "compress", "[Compressed conversation section]")
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig();

	assignMessageRefs(state, messages);

	const compressionPriorities = buildPriorityMap(config, state, messages);

	assert.equal(compressionPriorities.get("msg-assistant-1")?.priority, "high");
	injectMessageIds(state, config, messages, compressionPriorities);

	const assistantText = messages[1]?.parts[0],
		assistantTool = messages[1]?.parts[1];

	assert.doesNotMatch(assistantText.text, /dcp-message-id/);
	assert.match(assistantTool.state.output, /m0002<\/dcp-message-id>/);
	assert.match(assistantTool.state.output, /<dcp-message-id priority="high">m0002<\/dcp-message-id>/);
});

test("message-mode nudges append to existing text parts and list only earlier visible high-priority message IDs", () => {
	const sessionID = "ses_message_priority_nudges";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, repeatedWord("alpha", 6000), 1),
		buildMessage("msg-assistant-1", "assistant", sessionID, repeatedWord("beta", 6000), 2),
		buildMessage("msg-user-2", "user", sessionID, repeatedWord("gamma", 6000), 3),
		buildMessage("msg-assistant-2", "assistant", sessionID, repeatedWord("delta", 6000), 4)
	];

	const state = createSessionState(),
		config = buildConfig();

	assignMessageRefs(state, messages);
	state.prune.messages.byMessageId.set("msg-assistant-1", {
		tokenCount: 999,
		allBlockIds: [1],
		activeBlockIds: [1]
	});

	state.nudges.contextLimitAnchors.add("msg-user-2");

	const compressionPriorities = buildPriorityMap(config, state, messages);

	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	}, compressionPriorities);
	assert.equal(messages[2]?.parts.length, 1);

	const injectedNudge = messages[2]?.parts[0];

	assert.equal(injectedNudge?.type, "text");
	assert.match(injectedNudge.text, /\n\n<dcp-system-reminder>Base context nudge/);
	assert.match(injectedNudge.text, /Message priority context:/);
	assert.match(injectedNudge.text, /High-priority message IDs before this point: m0001/);
	assert.doesNotMatch(injectedNudge.text, /m0002/);
	assert.doesNotMatch(injectedNudge.text, /m0003/);
	assert.doesNotMatch(injectedNudge.text, /m0004/);
});

test("message-mode nudges exclude protected user messages from priority guidance", () => {
	const sessionID = "ses_message_blocked_priority_nudges";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, repeatedWord("alpha", 6000), 1),
		buildMessage("msg-assistant-1", "assistant", sessionID, repeatedWord("beta", 6000), 2),
		buildMessage("msg-user-2", "user", sessionID, repeatedWord("gamma", 6000), 3)
	];

	const state = createSessionState(),
		config = buildConfig();

	config.compress.protectUserMessages = true;

	assignMessageRefs(state, messages);
	state.nudges.contextLimitAnchors.add("msg-user-2");

	const compressionPriorities = buildPriorityMap(config, state, messages);

	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	}, compressionPriorities);

	const injectedNudge = messages[2]?.parts[0];

	assert.equal(injectedNudge?.type, "text");
	assert.match(injectedNudge.text, /High-priority message IDs before this point: m0002/);
	assert.doesNotMatch(injectedNudge.text, /m0001/);
});

test("range-mode nudges append to existing text parts before tool outputs", () => {
	const sessionID = "ses_range_nudge_injection";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, repeatedWord("alpha", 6000), 1),
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				textPart("msg-assistant-1", sessionID, "msg-assistant-1-part", "Working summary."),
				toolPart("msg-assistant-1", sessionID, "call-task-2", "task", "task output body")
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	state.prune.messages.activeBlockIds.add(7);
	state.nudges.contextLimitAnchors.add("msg-assistant-1");
	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	});

	assert.equal(messages[1]?.parts.length, 2);

	const injectedNudge = messages[1]?.parts[0],
		toolOutput = messages[1]?.parts[1];

	assert.equal(injectedNudge?.type, "text");
	assert.equal(toolOutput?.type, "tool");
	assert.match(injectedNudge.text, /\n\n<dcp-system-reminder>Base context nudge/);
	assert.match(injectedNudge.text, /Compressed block context:/);
	assert.match(injectedNudge.text, /Active compressed blocks in this session: 1 \(b7\)/);
	assert.equal(toolOutput.state.output, "task output body");
});

test("range-mode nudges inject only once for assistant messages with multiple text parts", () => {
	const sessionID = "ses_range_nudge_multi_text";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				textPart("msg-assistant-1", sessionID, "assistant-text-1", "First chunk."),
				textPart("msg-assistant-1", sessionID, "assistant-text-2", "Second chunk.")
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	state.nudges.contextLimitAnchors.add("msg-assistant-1");
	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	});

	assert.match((messages[1]?.parts[0]).text, /Base context nudge/);
	assert.doesNotMatch((messages[1]?.parts[1]).text, /Base context nudge/);
});

test("range-mode nudges skip empty assistant messages to avoid prefill (issue #463)", () => {
	const sessionID = "ses_range_nudge_empty_assistant";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-empty",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: []
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	state.nudges.contextLimitAnchors.add("msg-assistant-empty");
	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	});

	assert.equal(messages[1]?.parts.length, 0);
});

test("range-mode nudges skip assistant with only pending tool parts (issue #463)", () => {
	const sessionID = "ses_range_nudge_pending_tool";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-pending",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				{
					id: "pending-tool-part",
					messageID: "msg-assistant-pending",
					sessionID: sessionID,
					type: "tool",
					tool: "bash",
					callID: "call-pending-1",
					state: {
						status: "pending",
						input: { command: "ls" }
					}
				}
			]
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	state.nudges.contextLimitAnchors.add("msg-assistant-pending");
	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "<dcp-system-reminder>Base context nudge</dcp-system-reminder>",
		turnNudge: "<dcp-system-reminder>Base turn nudge</dcp-system-reminder>",
		iterationNudge: "<dcp-system-reminder>Base iteration nudge</dcp-system-reminder>"
	});

	assert.equal(messages[1]?.parts.length, 1);
	assert.equal(messages[1]?.parts[0]?.type, "tool");
});

test("range-mode nudges skip assistant messages with only empty text parts (issue #463)", () => {
	const sessionID = "ses_range_nudge_empty_text";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-empty-text",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [textPart("msg-assistant-empty-text", sessionID, "empty-text-part", "")]
		}
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	state.nudges.contextLimitAnchors.add("msg-assistant-empty-text");
	applyAnchoredNudges(state, config, messages, {
		system: "",
		compressRange: "",
		compressMessage: "",
		contextLimitNudge: "",
		turnNudge: "",
		iterationNudge: ""
	});

	assert.equal(messages[1]?.parts.length, 1);
	assert.equal((messages[1]?.parts[0]).text, "");
});

test("message-mode rendered compressed summaries mark block IDs as BLOCKED", () => {
	const sessionID = "ses_message_blocked_blocks";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Original request", 1),
		buildMessage("msg-assistant-1", "assistant", sessionID, "Follow-up", 2)
	];

	const state = createSessionState(),
		config = buildConfig("message"),
		logger = new Logger(false);

	state.prune.messages.byMessageId.set("msg-user-1", {
		tokenCount: 20,
		allBlockIds: [7],
		activeBlockIds: [7]
	});

	state.prune.messages.blocksById.set(7, {
		blockId: 7,
		runId: 1,
		active: true,
		deactivatedByUser: false,
		compressedTokens: 0,
		summaryTokens: 0,
		mode: "range",
		topic: "Earlier notes",
		batchTopic: "Earlier notes",
		startId: "m0001",
		endId: "m0001",
		anchorMessageId: "msg-user-1",
		compressMessageId: "msg-origin",
		includedBlockIds: [],
		consumedBlockIds: [],
		parentBlockIds: [],
		directMessageIds: ["msg-user-1"],
		directToolIds: [],
		effectiveMessageIds: ["msg-user-1"],
		effectiveToolIds: [],
		createdAt: 1,
		summary: `[Compressed conversation section]
Earlier summary

<dcp-message-id>b7</dcp-message-id>`
	});

	state.prune.messages.activeBlockIds.add(7);
	state.prune.messages.activeByAnchorMessageId.set("msg-user-1", 7);
	prune(state, logger, config, messages);

	const summaryText = messages[0]?.parts[0]?.text || "";

	assert.match(summaryText, /<dcp-message-id>BLOCKED<\/dcp-message-id>/);
	assert.doesNotMatch(summaryText, /<dcp-message-id>b7<\/dcp-message-id>/);
});

test("range-mode rendered compressed summaries keep block IDs", () => {
	const sessionID = "ses_range_visible_blocks";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Original request", 1),
		buildMessage("msg-assistant-1", "assistant", sessionID, "Follow-up", 2)
	];

	const state = createSessionState(),
		config = buildConfig("range"),
		logger = new Logger(false);

	state.prune.messages.byMessageId.set("msg-user-1", {
		tokenCount: 20,
		allBlockIds: [7],
		activeBlockIds: [7]
	});

	state.prune.messages.blocksById.set(7, {
		blockId: 7,
		runId: 1,
		active: true,
		deactivatedByUser: false,
		compressedTokens: 0,
		summaryTokens: 0,
		mode: "range",
		topic: "Earlier notes",
		batchTopic: "Earlier notes",
		startId: "m0001",
		endId: "m0001",
		anchorMessageId: "msg-user-1",
		compressMessageId: "msg-origin",
		includedBlockIds: [],
		consumedBlockIds: [],
		parentBlockIds: [],
		directMessageIds: ["msg-user-1"],
		directToolIds: [],
		effectiveMessageIds: ["msg-user-1"],
		effectiveToolIds: [],
		createdAt: 1,
		summary: `[Compressed conversation section]
Earlier summary

<dcp-message-id>b7</dcp-message-id>`
	});

	state.prune.messages.activeBlockIds.add(7);
	state.prune.messages.activeByAnchorMessageId.set("msg-user-1", 7);
	prune(state, logger, config, messages);

	const summaryText = messages[0]?.parts[0]?.text || "";

	assert.match(summaryText, /<dcp-message-id>b7<\/dcp-message-id>/);
	assert.doesNotMatch(summaryText, /<dcp-message-id>BLOCKED<\/dcp-message-id>/);
});

test("hallucination stripping removes all dcp-prefixed XML tags including variants", async () => {
	const text = "alpha" + '<dcp-message-id priority="low">m0008</dcp-message-id>' + '<dcp-message-id-extra priority="high">m0008</dcp-message-id-extra>' + "<dcp-system-reminder>strip this</dcp-system-reminder>" + "<dcp-system-reminder-extra>strip this too</dcp-system-reminder-extra>" + "omega";

	assert.equal(stripHallucinationsFromString(text), "alphaomega");

	const handler = createTextCompleteHandler(),
		output = { text: text };

	await handler({ sessionID: "session", messageID: "message", partID: "part" }, output);
	assert.equal(output.text, "alphaomega");
});

test("hallucination stripping removes colon and underscore dcp tag variants", async () => {
	assert.equal(stripHallucinationsFromString("beforeafter"), "beforeafter");
	assert.equal(stripHallucinationsFromString("startend"), "startend");
});

test("hallucination stripping removes orphan opening tags", async () => {
	assert.equal(stripHallucinationsFromString(`narration

<dcp:function_calls>

`), `narration



`);
	assert.equal(stripHallucinationsFromString('text <dcp:invoke name="edit"> more'), "text  more");
});

test("hallucination stripping removes orphan closing tags", async () => {
	assert.equal(stripHallucinationsFromString("text</dcp:function_calls> more"), "text more");
	assert.equal(stripHallucinationsFromString("before</dcp-message-id>after"), "beforeafter");
});

test("hallucination stripping handles nested dcp tags", async () => {
	assert.equal(stripHallucinationsFromString(`before<dcp:function_calls>
<dcp:invoke name="edit">content</dcp:invoke>
</dcp:function_calls>after`), `before
after`);
});

test("hallucination stripping handles mixed paired and orphan tags", async () => {
	assert.equal(stripHallucinationsFromString(`text
<dcp-message-id priority="low">m0045</dcp-message-id>
<dcp:function_calls>
`), `text


`);
});

test("hallucination stripping does not affect non-dcp tags", async () => {
	assert.equal(stripHallucinationsFromString("<div>hello</div> <system-reminder>keep</system-reminder>"), "<div>hello</div> <system-reminder>keep</system-reminder>");
});

test("hallucination stripping preserves content when dcp-message-id is mentioned in text (issue #556)", () => {
	const input = "The tag called `<dcp-message-id>` is used to track messages. " + `This text should survive.

` + "<dcp-message-id>m0369</dcp-message-id>";

	assert.equal(stripHallucinationsFromString(input), "The tag called `` is used to track messages. This text should survive.\n\n");
});

test("hallucination stripping handles priority on injected message-id suffixes", () => {
	const input = "The tag called `<dcp-message-id>` is used to track messages. " + `This text should survive.

` + '<dcp-message-id priority="low">m0370</dcp-message-id>';

	assert.equal(stripHallucinationsFromString(input), "The tag called `` is used to track messages. This text should survive.\n\n");
});

test("hallucination stripping removes trailing mXXXX</parameter> artifact (issue #555)", () => {
	assert.equal(stripHallucinationsFromString(`Total: maybe 20 lines changed.

m0340</parameter>

`), `Total: maybe 20 lines changed.

`);
});

test("hallucination stripping keeps dcp tags in tool output (issue #657)", () => {
	const sessionID = "ses_tool_output_tags";

	const output = `AAA

<dcp-system-reminder>
HELLO-INSIDE
</dcp-system-reminder>

ZZZ`;

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "cat /tmp/t.txt", 1),
		{
			info: {
				id: "msg-assistant-1",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [toolPart("msg-assistant-1", sessionID, "call-1", "bash", output)]
		}
	];

	stripHallucinations(messages);
	assert.equal((messages[1]?.parts[0]).state.output, output);
});

test("injectMessageIds skips empty assistant messages to avoid prefill (issue #463)", () => {
	const sessionID = "ses_empty_assistant";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-empty",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: []
		},
		buildMessage("msg-user-2", "user", sessionID, "continue", 3)
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	injectMessageIds(state, config, messages);

	const emptyAssistant = messages[1];

	assert.equal(emptyAssistant.parts.length, 0, "empty assistant should get no synthetic parts");
});

test("injectMessageIds skips assistant with only pending tool parts (issue #463)", () => {
	const sessionID = "ses_pending_tool_assistant";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-pending",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [
				{
					id: "pending-tool-part",
					messageID: "msg-assistant-pending",
					sessionID: sessionID,
					type: "tool",
					tool: "bash",
					callID: "call-pending-1",
					state: {
						status: "pending",
						input: { command: "ls" }
					}
				}
			]
		},
		buildMessage("msg-user-2", "user", sessionID, "continue", 3)
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	injectMessageIds(state, config, messages);

	const pendingAssistant = messages[1];

	assert.equal(pendingAssistant.parts.length, 1, "assistant with only pending tools should not get a synthetic text part");
	assert.equal(pendingAssistant.parts[0].type, "tool");
});

test("injectMessageIds skips assistant with empty text part (issue #463)", () => {
	const sessionID = "ses_empty_text_assistant";

	const messages = [
		buildMessage("msg-user-1", "user", sessionID, "Hello", 1),
		{
			info: {
				id: "msg-assistant-empty-text",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				time: { created: 2 }
			},
			parts: [textPart("msg-assistant-empty-text", sessionID, "empty-text-part", "")]
		},
		buildMessage("msg-user-2", "user", sessionID, "continue", 3)
	];

	const state = createSessionState(),
		config = buildConfig("range");

	assignMessageRefs(state, messages);
	injectMessageIds(state, config, messages);

	const emptyTextAssistant = messages[1];

	assert.equal(emptyTextAssistant.parts.length, 1, "should not add a synthetic part");
	assert.equal(emptyTextAssistant.parts[0].text, "", "empty text part should remain untouched");
});
