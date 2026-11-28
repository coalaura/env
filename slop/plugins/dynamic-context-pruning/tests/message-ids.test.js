import assert from "node:assert/strict";
import test from "node:test";
import { Logger } from "../logger.js";
import { assignMessageRefs } from "../message-ids.js";
import { checkSession, createSessionState } from "../state/index.js";

function textPart(messageID, sessionID, id, text) {
	return {
		id: id,
		messageID: messageID,
		sessionID: sessionID,
		type: "text",
		text: text
	};
}

function buildCompactedMessages(sessionID, summaryInfo = { finish: "stop" }) {
	return [
		{
			info: {
				id: "msg-assistant-summary",
				role: "assistant",
				sessionID: sessionID,
				agent: "assistant",
				summary: true,
				time: { created: 2 },
				...summaryInfo
			},
			parts: [
				textPart("msg-assistant-summary", sessionID, "msg-assistant-summary-part", "Compaction summary")
			]
		},
		{
			info: {
				id: "msg-user-follow-up",
				role: "user",
				sessionID: sessionID,
				agent: "assistant",
				model: {
					providerID: "anthropic",
					modelID: "claude-test"
				},
				time: { created: 3 }
			},
			parts: [
				textPart("msg-user-follow-up", sessionID, "msg-user-follow-up-part", "Continue after compaction")
			]
		}
	];
}

test("checkSession resets message id aliases after native compaction", async () => {
	const sessionID = `ses_message_ids_after_compaction_${Date.now()}`,
		messages = buildCompactedMessages(sessionID),
		state = createSessionState(),
		logger = new Logger(false);

	state.sessionId = sessionID;

	state.messageIds.byRawId.set("old-message-9998", "m9998");
	state.messageIds.byRawId.set("old-message-9999", "m9999");
	state.messageIds.byRef.set("m9998", "old-message-9998");
	state.messageIds.byRef.set("m9999", "old-message-9999");
	state.messageIds.nextRef = 9999;

	await checkSession({}, state, logger, messages, false);
	assert.equal(state.lastCompaction, 2);
	assert.equal(state.messageIds.byRawId.size, 0);
	assert.equal(state.messageIds.byRef.size, 0);
	assert.equal(state.messageIds.nextRef, 1);

	const assigned = assignMessageRefs(state, messages);

	assert.equal(assigned, 2);
	assert.equal(state.messageIds.byRawId.get("msg-assistant-summary"), "m0001");
	assert.equal(state.messageIds.byRawId.get("msg-user-follow-up"), "m0002");
	assert.equal(state.messageIds.byRef.get("m0001"), "msg-assistant-summary");
	assert.equal(state.messageIds.byRef.get("m0002"), "msg-user-follow-up");
	assert.equal(state.messageIds.nextRef, 3);
});

test("checkSession ignores failed native compaction summaries", async () => {
	const failedSummaries = [{}, { finish: "error", error: { name: "UnknownError" } }];

	for (const summaryInfo of failedSummaries) {
		const sessionID = `ses_message_ids_failed_compaction_${Date.now()}`,
			messages = buildCompactedMessages(sessionID, summaryInfo),
			state = createSessionState(),
			logger = new Logger(false);

		state.sessionId = sessionID;

		state.messageIds.byRawId.set("old-message", "m0001");
		state.messageIds.byRef.set("m0001", "old-message");
		state.messageIds.nextRef = 2;

		await checkSession({}, state, logger, messages, false);
		assert.equal(state.lastCompaction, 0);
		assert.equal(state.messageIds.byRef.get("m0001"), "old-message");
		assert.equal(state.messageIds.nextRef, 2);
	}
});
