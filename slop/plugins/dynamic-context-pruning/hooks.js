import { assignMessageRefs } from "./message-ids.js";
import {
	buildPriorityMap,
	buildToolIdList,
	injectCompressNudges,
	injectExtendedSubAgentResults,
	injectMessageIds,
	prune,
	stripHallucinations,
	stripHallucinationsFromString,
	stripStaleMetadata,
	syncCompressionBlocks
} from "./messages/index.js";
import { renderSystemPrompt } from "./prompts/index.js";
import { buildProtectedToolsExtension } from "./prompts/extensions/system.js";
import {
	applyPendingCompressionDurations,
	buildCompressionTimingKey,
	consumeCompressionStart,
	resolveCompressionDuration
} from "./compress/timing.js";
import { filterMessages, filterMessagesInPlace } from "./messages/shape.js";
import {
	applyPendingManualTrigger,
	handleContextCommand,
	handleDecompressCommand,
	handleHelpCommand,
	handleManualToggleCommand,
	handleManualTriggerCommand,
	handleRecompressCommand,
	handleStatsCommand,
	handleSweepCommand
} from "./commands/index.js";
import { compressPermission, syncCompressPermissionState } from "./compress-permission.js";
import {
	checkSession,
	ensureSessionInitialized,
	saveSessionState,
	syncToolCache
} from "./state/index.js";
import { cacheSystemPromptTokens } from "./ui/utils.js";

const INTERNAL_AGENT_SIGNATURES = [
	"You are a title generator",
	"You are a helpful AI assistant tasked with summarizing conversations",
	"You are an anchored context summarization assistant for coding sessions",
	"Summarize what was done in this conversation"
];

function isInternalAgentCall(systemPrompts) {
	const primaryPrompt = systemPrompts[0];

	if (typeof primaryPrompt !== "string" || primaryPrompt.length === 0) {
		return false;
	}

	return INTERNAL_AGENT_SIGNATURES.some((signature) => primaryPrompt.includes(signature));
}

export function createSystemPromptHandler(state, logger, config, prompts) {
	return async (input, output) => {
		if (input.model?.limit?.context) {
			state.modelContextLimit = input.model.limit.context;

			logger.debug("Cached model context limit", { limit: state.modelContextLimit });
		}

		if (state.isSubAgent && !config.experimental.allowSubAgents) {
			return;
		}

		if (isInternalAgentCall(output.system)) {
			logger.info("Skipping DCP system prompt injection for internal agent");

			return;
		}

		const effectivePermission = input.sessionID && state.sessionId === input.sessionID ? compressPermission(state, config) : config.compress.permission;

		if (effectivePermission === "deny") {
			return;
		}

		prompts.reload();

		const runtimePrompts = prompts.getRuntimePrompts(),
			newPrompt = renderSystemPrompt(runtimePrompts, buildProtectedToolsExtension(config.compress.protectedTools), !!state.manualMode, state.isSubAgent && config.experimental.allowSubAgents);

		if (output.system.length > 0) {
			output.system[output.system.length - 1] += "\n\n" + newPrompt;
		} else {
			output.system.push(newPrompt);
		}
	};
}

export function createChatMessageTransformHandler(client, state, logger, config, prompts, hostPermissions) {
	return async (input, output) => {
		const receivedMessages = Array.isArray(output.messages) ? output.messages.length : 0,
			messages = filterMessagesInPlace(output.messages);

		if (messages.length !== receivedMessages) {
			logger.warn("Skipping messages with unexpected shape during chat transform", {
				received: receivedMessages,
				usable: messages.length
			});
		}

		await checkSession(client, state, logger, output.messages, config.manualMode.enabled);

		syncCompressPermissionState(state, config, hostPermissions, output.messages);

		if (state.isSubAgent && !config.experimental.allowSubAgents) {
			return;
		}

		stripHallucinations(output.messages);
		cacheSystemPromptTokens(state, output.messages);
		assignMessageRefs(state, output.messages);
		syncCompressionBlocks(state, logger, output.messages);
		syncToolCache(state, config, logger, output.messages);
		buildToolIdList(state, output.messages);
		prune(state, logger, config, output.messages);

		await injectExtendedSubAgentResults(client, state, logger, output.messages, config.experimental.allowSubAgents);

		const compressionPriorities = buildPriorityMap(config, state, output.messages);

		prompts.reload();

		injectCompressNudges(state, config, logger, output.messages, prompts.getRuntimePrompts(), compressionPriorities);
		injectMessageIds(state, config, output.messages, compressionPriorities);
		applyPendingManualTrigger(state, output.messages, logger);
		stripStaleMetadata(output.messages);

		if (state.sessionId) {
			await logger.saveContext(state.sessionId, output.messages);
		}
	};
}

export function createCommandExecuteHandler(client, state, logger, config, workingDirectory, hostPermissions) {
	return async (input, output) => {
		if (!config.commands.enabled) {
			return;
		}

		if (input.command === "dcp" || input.command === "dcp-compress") {
			const messagesResponse = await client.session.messages({
				path: { id: input.sessionID }
			});

			const messages = filterMessages(messagesResponse.data || messagesResponse);

			await ensureSessionInitialized(client, state, input.sessionID, logger, messages, config.manualMode.enabled);

			syncCompressPermissionState(state, config, hostPermissions, messages);

			const effectivePermission = compressPermission(state, config);

			if (effectivePermission === "deny") {
				return;
			}

			const args = (input.arguments || "").trim().split(/\s+/).filter(Boolean),
				isCompressCommand = input.command === "dcp-compress",
				subcommand = isCompressCommand ? "compress" : args[0]?.toLowerCase() || "",
				subArgs = isCompressCommand ? args : args.slice(1);

			const commandCtx = {
				client: client,
				state: state,
				config: config,
				logger: logger,
				sessionId: input.sessionID,
				messages: messages
			};

			if (subcommand === "context") {
				await handleContextCommand(commandCtx);

				return;
			}

			if (subcommand === "stats") {
				await handleStatsCommand(commandCtx);

				return;
			}

			if (subcommand === "sweep") {
				await handleSweepCommand({
					...commandCtx,
					args: subArgs,
					workingDirectory: workingDirectory
				});

				return;
			}

			if (subcommand === "manual") {
				await handleManualToggleCommand(commandCtx, subArgs[0]?.toLowerCase());

				return;
			}

			if (subcommand === "compress") {
				const userFocus = subArgs.join(" ").trim(),
					prompt = await handleManualTriggerCommand(commandCtx, "compress", userFocus);

				if (!prompt) {
					throw new Error("__DCP_MANUAL_TRIGGER_BLOCKED__");
				}

				state.manualMode = "compress-pending";
				state.pendingManualTrigger = {
					sessionId: input.sessionID,
					prompt: prompt
				};

				const rawArgs = (input.arguments || "").trim();

				output.parts.length = 0;

				output.parts.push({
					type: "text",
					text: isCompressCommand ? rawArgs ? `/dcp-compress ${rawArgs}` : "/dcp-compress" : rawArgs ? `/dcp ${rawArgs}` : `/dcp ${subcommand}`
				});

				return;
			}

			if (subcommand === "decompress") {
				await handleDecompressCommand({
					...commandCtx,
					args: subArgs
				});

				return;
			}

			if (subcommand === "recompress") {
				await handleRecompressCommand({
					...commandCtx,
					args: subArgs
				});

				return;
			}

			await handleHelpCommand(commandCtx);

			return;
		}
	};
}

export function createTextCompleteHandler() {
	return async (_input, output) => {
		output.text = stripHallucinationsFromString(output.text);
	};
}

export function createEventHandler(state, logger) {
	return async (input) => {
		const eventTime = typeof input.event?.time === "number" && Number.isFinite(input.event.time) ? input.event.time : typeof input.event?.properties?.time === "number" && Number.isFinite(input.event.properties.time) ? input.event.properties.time : undefined;

		if (input.event.type !== "message.part.updated") {
			return;
		}

		const part = input.event.properties?.part;

		if (part?.type !== "tool" || part.tool !== "compress") {
			return;
		}

		if (part.state.status === "pending") {
			if (typeof part.callID !== "string" || typeof part.messageID !== "string") {
				return;
			}

			const startedAt = eventTime ?? Date.now(),
				key = buildCompressionTimingKey(part.messageID, part.callID);

			if (state.compressionTiming.startsByCallId.has(key)) {
				return;
			}

			state.compressionTiming.startsByCallId.set(key, startedAt);
			logger.debug("Recorded compression start", {
				messageID: part.messageID,
				callID: part.callID,
				startedAt: startedAt
			});

			return;
		}

		if (part.state.status === "completed") {
			if (typeof part.callID !== "string" || typeof part.messageID !== "string") {
				return;
			}

			const key = buildCompressionTimingKey(part.messageID, part.callID),
				start = consumeCompressionStart(state, part.messageID, part.callID),
				durationMs = resolveCompressionDuration(start, eventTime, part.state.time);

			if (typeof durationMs !== "number") {
				return;
			}

			state.compressionTiming.pendingByCallId.set(key, {
				messageId: part.messageID,
				callId: part.callID,
				durationMs: durationMs
			});

			const updates = applyPendingCompressionDurations(state);

			if (updates === 0) {
				return;
			}

			await saveSessionState(state, logger);
			logger.info("Attached compression time to blocks", {
				messageID: part.messageID,
				callID: part.callID,
				blocks: updates,
				durationMs: durationMs
			});

			return;
		}

		if (part.state.status === "running") {
			return;
		}

		if (typeof part.callID === "string" && typeof part.messageID === "string") {
			state.compressionTiming.startsByCallId.delete(buildCompressionTimingKey(part.messageID, part.callID));
		}
	};
}
