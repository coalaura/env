import { sendIgnoredMessage } from "../ui/notification.js";
import { formatPrunedItemsList } from "../ui/utils.js";
import { getCurrentParams, getTotalToolTokens } from "../token-utils.js";
import { isIgnoredUserMessage } from "../messages/query.js";
import { buildToolIdList } from "../messages/utils.js";
import { saveSessionState } from "../state/persistence.js";
import { isMessageCompacted } from "../state/utils.js";
import { isToolProtected } from "../protected-patterns.js";
import { syncToolCache } from "../state/tool-cache.js";

function findLastUserMessageIndex(messages) {
	for (let i = messages.length - 1;i >= 0; i--) {
		const msg = messages[i];

		if (msg.info.role === "user" && !isIgnoredUserMessage(msg)) {
			return i;
		}
	}

	return -1;
}

function collectToolIdsAfterIndex(state, messages, afterIndex) {
	const toolIds = [];

	for (let i = afterIndex + 1;i < messages.length; i++) {
		const msg = messages[i];

		if (isMessageCompacted(state, msg)) {
			continue;
		}

		const parts = Array.isArray(msg.parts) ? msg.parts : [];

		if (parts.length > 0) {
			for (const part of parts) {
				if (part.type === "tool" && part.callID && part.tool) {
					toolIds.push(part.callID);
				}
			}
		}
	}

	return toolIds;
}

function formatNoUserMessage() {
	const lines = [];

	lines.push("╭───────────────────────────────────────────────────────────╮");
	lines.push("│                      DCP Sweep                            │");
	lines.push("╰───────────────────────────────────────────────────────────╯");
	lines.push("");
	lines.push("Nothing swept: no user message found.");

	return lines.join("\n");
}

function formatSweepMessage(toolCount, tokensSaved, mode, toolIds, toolMetadata, workingDirectory, skippedProtected) {
	const lines = [];

	lines.push("╭───────────────────────────────────────────────────────────╮");
	lines.push("│                      DCP Sweep                            │");
	lines.push("╰───────────────────────────────────────────────────────────╯");
	lines.push("");

	if (toolCount === 0) {
		if (mode === "since-user") {
			lines.push("No tools found since the previous user message.");
		} else {
			lines.push(`No tools found to sweep.`);
		}

		if (skippedProtected && skippedProtected > 0) {
			lines.push(`(${skippedProtected} protected tool(s) skipped)`);
		}
	} else {
		if (mode === "since-user") {
			lines.push(`Swept ${toolCount} tool(s) since the previous user message.`);
		} else {
			lines.push(`Swept the last ${toolCount} tool(s).`);
		}

		lines.push(`Tokens saved: ~${tokensSaved.toLocaleString()}`);

		if (skippedProtected && skippedProtected > 0) {
			lines.push(`(${skippedProtected} protected tool(s) skipped)`);
		}

		lines.push("");

		const itemLines = formatPrunedItemsList(toolIds, toolMetadata, workingDirectory);

		lines.push(...itemLines);
	}

	return lines.join("\n");
}

export async function handleSweepCommand(ctx) {
	const { client: client, state: state, config: config, logger: logger, sessionId: sessionId, messages: messages, args: args, workingDirectory: workingDirectory } = ctx;

	const params = getCurrentParams(state, messages, logger),
		protectedTools = config.commands.protectedTools;

	syncToolCache(state, config, logger, messages);
	buildToolIdList(state, messages);

	const numArg = args[0] ? parseInt(args[0], 10) : null,
		isLastNMode = numArg !== null && !isNaN(numArg) && numArg > 0;

	let toolIdsToSweep,
		mode;

	if (isLastNMode) {
		mode = "last-n";

		const startIndex = Math.max(0, state.toolIdList.length - numArg);

		toolIdsToSweep = state.toolIdList.slice(startIndex);

		logger.info(`Sweep command: last ${numArg} mode, found ${toolIdsToSweep.length} tools`);
	} else {
		mode = "since-user";

		const lastUserMsgIndex = findLastUserMessageIndex(messages);

		if (lastUserMsgIndex === -1) {
			const message = formatNoUserMessage();

			await sendIgnoredMessage(client, sessionId, message, params, logger);

			logger.info("Sweep command: no user message found");

			return;
		} else {
			toolIdsToSweep = collectToolIdsAfterIndex(state, messages, lastUserMsgIndex);

			logger.info(`Sweep command: found last user at index ${lastUserMsgIndex}, sweeping ${toolIdsToSweep.length} tools`);
		}
	}

	const newToolIds = toolIdsToSweep.filter((id) => {
		if (state.prune.tools.has(id)) {
			return false;
		}

		const entry = state.toolParameters.get(id);

		if (!entry) {
			return true;
		}

		if (isToolProtected(entry.tool, entry.parameters, protectedTools, config.protectedFilePatterns, entry.metadata)) {
			logger.debug(`Sweep: skipping protected tool ${entry.tool} (${id})`);
			return false;
		}

		return true;
	});

	const skippedProtected = toolIdsToSweep.filter((id) => {
		const entry = state.toolParameters.get(id);

		if (!entry) {
			return false;
		}

		return isToolProtected(entry.tool, entry.parameters, protectedTools, config.protectedFilePatterns, entry.metadata);
	}).length;

	if (newToolIds.length === 0) {
		const message = formatSweepMessage(0, 0, mode, [], new Map, workingDirectory, skippedProtected);

		await sendIgnoredMessage(client, sessionId, message, params, logger);

		logger.info("Sweep command: no new tools to sweep", { skippedProtected: skippedProtected });

		return;
	}

	const tokensSaved = getTotalToolTokens(state, newToolIds);

	for (const id of newToolIds) {
		const entry = state.toolParameters.get(id);

		state.prune.tools.set(id, entry?.tokenCount ?? 0);
	}

	state.stats.pruneTokenCounter += tokensSaved;
	state.stats.totalPruneTokens += state.stats.pruneTokenCounter;
	state.stats.pruneTokenCounter = 0;

	const toolMetadata = new Map;

	for (const id of newToolIds) {
		const entry = state.toolParameters.get(id);

		if (entry) {
			toolMetadata.set(id, entry);
		}
	}

	saveSessionState(state, logger).catch((err) => logger.error("Failed to persist state after sweep", { error: err.message }));

	const message = formatSweepMessage(newToolIds.length, tokensSaved, mode, newToolIds, toolMetadata, workingDirectory, skippedProtected);

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	logger.info("Sweep command completed", {
		toolsSwept: newToolIds.length,
		tokensSaved: tokensSaved,
		skippedProtected: skippedProtected,
		mode: mode,
		tools: Array.from(toolMetadata.entries()).map(([id, entry]) => ({
			id: id,
			tool: entry.tool
		}))
	});
}
