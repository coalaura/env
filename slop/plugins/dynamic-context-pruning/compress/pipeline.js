import { ensureSessionInitialized, refreshManualMode } from "../state/index.js";
import { saveSessionState } from "../state/persistence.js";
import { assignMessageRefs } from "../message-ids.js";
import { isIgnoredUserMessage } from "../messages/query.js";
import { deduplicate, purgeErrors } from "../strategies/index.js";
import { getCurrentParams } from "../token-utils.js";
import { sendCompressNotification } from "../ui/notification.js";
import { buildSearchContext, fetchSessionMessages } from "./search.js";
import { applyPendingCompressionDurations } from "./timing.js";

export async function prepareSession(ctx, toolCtx, title) {
	await refreshManualMode(ctx.state, toolCtx.sessionID, ctx.logger, ctx.config.manualMode.enabled);

	if (ctx.state.manualMode && ctx.state.manualMode !== "compress-pending") {
		throw new Error("Manual mode: compress blocked. Do not retry until `<compress triggered manually>` appears in user context.");
	}

	await toolCtx.ask({
		permission: "compress",
		patterns: ["*"],
		always: ["*"],
		metadata: {}
	});

	toolCtx.metadata({ title: title });

	const rawMessages = await fetchSessionMessages(ctx.client, toolCtx.sessionID);

	await ensureSessionInitialized(ctx.client, ctx.state, toolCtx.sessionID, ctx.logger, rawMessages, ctx.config.manualMode.enabled);

	assignMessageRefs(ctx.state, rawMessages);
	deduplicate(ctx.state, ctx.logger, ctx.config, rawMessages);
	purgeErrors(ctx.state, ctx.logger, ctx.config, rawMessages);

	return {
		rawMessages: rawMessages,
		searchContext: buildSearchContext(ctx.state, rawMessages)
	};
}

export async function finalizeSession(ctx, toolCtx, rawMessages, entries, batchTopic) {
	if (ctx.state.manualMode === "compress-pending") {
		ctx.state.manualMode = false;
		await refreshManualMode(ctx.state, toolCtx.sessionID, ctx.logger, ctx.config.manualMode.enabled);
	}

	applyPendingCompressionDurations(ctx.state);

	await saveSessionState(ctx.state, ctx.logger);

	const params = getCurrentParams(ctx.state, rawMessages, ctx.logger),
		sessionMessageIds = rawMessages.filter((msg) => !isIgnoredUserMessage(msg)).map((msg) => msg.info.id);

	await sendCompressNotification(ctx.client, ctx.logger, ctx.config, ctx.state, toolCtx.sessionID, entries, batchTopic, sessionMessageIds, params);
}
