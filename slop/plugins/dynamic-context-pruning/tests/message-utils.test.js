import assert from "node:assert/strict";
import test from "node:test";
import { isIgnoredUserMessage } from "../messages/query.js";

function buildMessage(role, parts) {
	const sessionID = "ses_message_utils";

	const info = role === "user" ? {
		id: `msg-${role}`,
		role: role,
		sessionID: sessionID,
		agent: "assistant",
		model: {
			providerID: "anthropic",
			modelID: "claude-test"
		},
		time: { created: 1 }
	} : {
		id: `msg-${role}`,
		role: role,
		sessionID: sessionID,
		agent: "assistant",
		time: { created: 1 }
	};

	return {
		info: info,
		parts: parts
	};
}

test("isIgnoredUserMessage only ignores user messages", () => {
	const ignoredUserMessage = buildMessage("user", []),
		assistantMessage = buildMessage("assistant", []);

	assert.equal(isIgnoredUserMessage(ignoredUserMessage), true);
	assert.equal(isIgnoredUserMessage(assistantMessage), false);
});
