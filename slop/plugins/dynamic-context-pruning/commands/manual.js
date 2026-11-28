import { sendIgnoredMessage } from "../ui/notification.js";
import { saveManualModeSetting } from "../state/persistence.js";
import { getCurrentParams } from "../token-utils.js";
import { buildCompressedBlockGuidance } from "../prompts/extensions/nudge.js";
import { isIgnoredUserMessage } from "../messages/query.js";

const MANUAL_MODE_ON = "Manual mode is now ON. Use /dcp-compress to trigger context tools manually.";

const MANUAL_MODE_OFF = "Manual mode is now OFF.";

const COMPRESS_TRIGGER_PROMPT = [
	"<compress triggered manually>",
	"Manual mode trigger received. You must now use the compress tool.",
	"Find the most significant completed conversation content that can be compressed into a high-fidelity technical summary.",
	"Follow the active compress mode, preserve all critical implementation details, and choose safe targets.",
	"Return after compress with a brief explanation of what content was compressed."
].join("\n\n");

function getTriggerPrompt(tool, state, config, userFocus) {
	const base = COMPRESS_TRIGGER_PROMPT,
		compressedBlockGuidance = config.compress.mode === "message" ? "" : buildCompressedBlockGuidance(state),
		sections = [base, compressedBlockGuidance];

	if (userFocus && userFocus.trim().length > 0) {
		sections.push(`Additional user focus:
${userFocus.trim()}`);
	}

	return sections.join("\n\n");
}

export async function handleManualToggleCommand(ctx, modeArg) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages } = ctx;

	if (modeArg === "on") {
		state.manualMode = "active";
	} else if (modeArg === "off") {
		state.manualMode = false;
	} else {
		state.manualMode = state.manualMode ? false : "active";
	}

	const params = getCurrentParams(state, messages, logger);

	await sendIgnoredMessage(client, sessionId, state.manualMode ? MANUAL_MODE_ON : MANUAL_MODE_OFF, params, logger);
	await saveManualModeSetting(sessionId, !!state.manualMode, logger);

	logger.info("Manual mode toggled", { manualMode: state.manualMode });
}

export async function handleManualTriggerCommand(ctx, tool, userFocus) {
	return getTriggerPrompt(tool, ctx.state, ctx.config, userFocus);
}

export function applyPendingManualTrigger(state, messages, logger) {
	const pending = state.pendingManualTrigger;

	if (!pending) {
		return;
	}

	if (!state.sessionId || pending.sessionId !== state.sessionId) {
		state.pendingManualTrigger = null;

		return;
	}

	for (let i = messages.length - 1;i >= 0; i--) {
		const msg = messages[i];

		if (msg.info.role !== "user" || isIgnoredUserMessage(msg)) {
			continue;
		}

		for (const part of msg.parts) {
			if (part.type !== "text" || part.ignored || part.synthetic) {
				continue;
			}

			part.text = pending.prompt;
			state.pendingManualTrigger = null;

			logger.debug("Applied manual prompt", { sessionId: pending.sessionId });

			return;
		}
	}

	state.pendingManualTrigger = null;
}
