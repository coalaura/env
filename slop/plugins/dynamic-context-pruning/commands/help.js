import { compressPermission } from "../compress-permission.js";
import { sendIgnoredMessage } from "../ui/notification.js";
import { getCurrentParams } from "../token-utils.js";

const TUI_COMMANDS = [
	["DCP Context", "Show token usage breakdown for current session"],
	["DCP Stats", "Show DCP pruning statistics"],
	["DCP Help", "Show this help in a modal"]
];

const TOOL_COMMANDS = {
	compress: ["/dcp-compress [focus]", "Trigger manual compress tool execution"],
	decompress: ["/dcp decompress <n>", "Restore selected compression"],
	recompress: ["/dcp recompress <n>", "Re-apply a user-decompressed compression"]
};

function getVisibleCommands(state, config) {
	const commands = [...TUI_COMMANDS];

	if (compressPermission(state, config) !== "deny") {
		commands.push(TOOL_COMMANDS.compress);
	}

	return commands;
}

export function formatHelpMessage(state, config) {
	const commands = getVisibleCommands(state, config),
		colWidth = Math.max(...commands.map(([cmd]) => cmd.length)) + 4,
		lines = [];

	lines.push("╭─────────────────────────────────────────────────────────────────────────╮");
	lines.push("│                              DCP Commands                               │");
	lines.push("╰─────────────────────────────────────────────────────────────────────────╯");
	lines.push("");
	lines.push(`  ${"Manual mode:".padEnd(colWidth)}${state.manualMode ? "ON" : "OFF"}`);
	lines.push("");
	lines.push("  Open the command palette for DCP modal commands.");
	lines.push("  Use /dcp-compress [focus] when you want DCP to ask the model to run compression.");
	lines.push("");

	for (const [cmd, desc] of commands) {
		lines.push(`  ${cmd.padEnd(colWidth)}${desc}`);
	}

	lines.push("");

	return lines.join("\n");
}

export async function handleHelpCommand(ctx) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages } = ctx,
		{ config: config } = ctx;

	const message = formatHelpMessage(state, config),
		params = getCurrentParams(state, messages, logger);

	await sendIgnoredMessage(client, sessionId, message, params, logger);

	logger.info("Help command executed");
}
