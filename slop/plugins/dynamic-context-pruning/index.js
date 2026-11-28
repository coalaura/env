// Derived from opencode-dynamic-context-pruning 3.2.1 (AGPL-3.0-or-later).
// https://github.com/Opencode-DCP/opencode-dynamic-context-pruning
import { getConfig } from "./config.js";
import { createCompressMessageTool, createCompressRangeTool } from "./compress/index.js";
import { compressDisabledByOpencode, hasExplicitToolPermission } from "./host-permissions.js";
import { Logger } from "./logger.js";
import { createSessionState, ensureSessionInitialized } from "./state/index.js";
import { syncCompressPermissionState } from "./compress-permission.js";
import { filterMessages } from "./messages/shape.js";
import { Sessions, messageSessionId } from "./sessions.js";
import { PromptStore } from "./prompts/store.js";
import {
	createChatMessageTransformHandler,
	createCommandExecuteHandler,
	createEventHandler,
	createSystemPromptHandler,
	createTextCompleteHandler
} from "./hooks.js";
import { configureClientAuth, isSecureMode } from "./auth.js";

export default async function dynamicContextPruning(context) {
	const config = getConfig(context);

	if (!config.enabled) {
		return {};
	}

	const logger = new Logger(config.debug),
		prompts = new PromptStore(logger, context.directory, config.experimental.customPrompts);

	const hostPermissions = {
		global: undefined,
		agents: {}
	};

	if (isSecureMode()) {
		configureClientAuth(context.client);
	}

	logger.info("DCP initialized", { strategies: config.strategies });

	const createTool = config.compress.mode === "message" ? createCompressMessageTool : createCompressRangeTool;

	const toolContext = {
		client: context.client,
		logger: logger,
		config: config,
		prompts: prompts
	};

	const sessions = new Sessions(() => {
		const state = createSessionState();

		return {
			state: state,
			system: createSystemPromptHandler(state, logger, config, prompts),
			messages: createChatMessageTransformHandler(context.client, state, logger, config, prompts, hostPermissions),
			command: createCommandExecuteHandler(context.client, state, logger, config, context.directory, hostPermissions),
			event: createEventHandler(state, logger),
			tool: createTool({ ...toolContext, state: state })
		};
	});

	const tools = {};

	if (config.compress.permission !== "deny") {
		const definition = createTool({ ...toolContext, state: createSessionState() });

		tools.compress = {
			get description() {
				return definition.description;
			},
			args: definition.args,
			execute(args, toolInput) {
				return sessions.run(toolInput.sessionID, (runtime) => runtime.tool.execute(args, toolInput));
			}
		};
	}

	return {
		async "experimental.chat.system.transform"(input, output) {
			if (!input.sessionID) {
				return;
			}

			await sessions.run(input.sessionID, async (runtime) => {
				if (!runtime.state.sessionId) {
					const response = await context.client.session.messages({ path: { id: input.sessionID } }),
						messages = filterMessages(response.data || response);

					await ensureSessionInitialized(context.client, runtime.state, input.sessionID, logger, messages, config.manualMode.enabled);
					syncCompressPermissionState(runtime.state, config, hostPermissions, messages);
				}

				await runtime.system(input, output);
			});
		},
		async "experimental.chat.messages.transform"(input, output) {
			const sessionId = messageSessionId(input, output.messages);

			if (sessionId) {
				await sessions.run(sessionId, (runtime) => runtime.messages(input, output));
			}
		},
		"experimental.text.complete": createTextCompleteHandler(),
		async "command.execute.before"(input, output) {
			if (input.command === "dcp" || input.command === "dcp-compress") {
				await sessions.run(input.sessionID, (runtime) => runtime.command(input, output));
			}
		},
		async event(input) {
			if (input.event.type === "session.deleted") {
				await sessions.delete(input.event.properties?.info?.id);

				return;
			}

			const part = input.event.properties?.part;

			if (input.event.type !== "message.part.updated" || part?.type !== "tool" || part.tool !== "compress" || !part.sessionID) {
				return;
			}

			// Timing events must be observed while a tool is running, not queued behind it.
			await sessions.get(part.sessionID).runtime.event(input);
		},
		tool: tools,
		async config(opencodeConfig) {
			if (config.compress.permission !== "deny" && compressDisabledByOpencode(opencodeConfig.permission)) {
				config.compress.permission = "deny";
			}

			if (config.commands.enabled && config.compress.permission !== "deny") {
				opencodeConfig.command ??= {};
				opencodeConfig.command["dcp-compress"] = {
					template: "",
					description: "Trigger DCP manual compression with: /dcp-compress [focus]"
				};
			}

			if (config.compress.permission !== "deny" && !config.experimental.allowSubAgents) {
				const existing = opencodeConfig.experimental?.primary_tools ?? [];

				opencodeConfig.experimental = {
					...opencodeConfig.experimental,
					primary_tools: existing.includes("compress") ? existing : [...existing, "compress"]
				};
			}

			if (!hasExplicitToolPermission(opencodeConfig.permission, "compress")) {
				const permission = opencodeConfig.permission ?? {};

				opencodeConfig.permission = {
					...permission,
					compress: config.compress.permission
				};
			}

			hostPermissions.global = opencodeConfig.permission;
			hostPermissions.agents = Object.fromEntries(Object.entries(opencodeConfig.agent ?? {}).map(([name, agent]) => [name, agent?.permission]));
		}
	};
}
