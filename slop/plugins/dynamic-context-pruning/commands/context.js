import { sendIgnoredMessage } from "../ui/notification.js";
import { formatTokenCount } from "../ui/utils.js";
import { isIgnoredUserMessage } from "../messages/query.js";
import { isMessageCompacted } from "../state/utils.js";
import { countTokens, extractCompletedToolOutput, getCurrentParams } from "../token-utils.js";

export function analyzeContextTokens(state, messages) {
	const breakdown = {
		system: 0,
		user: 0,
		assistant: 0,
		tools: 0,
		toolCount: 0,
		toolsInContextCount: 0,
		prunedTokens: state.stats.totalPruneTokens,
		prunedToolCount: 0,
		prunedMessageCount: 0,
		total: 0
	};
	let firstAssistant;

	for (const msg of messages) {
		if (msg.info.role === "assistant") {
			const assistantInfo = msg.info;
			if (assistantInfo.tokens?.input > 0 || assistantInfo.tokens?.cache?.read > 0 || assistantInfo.tokens?.cache?.write > 0) {
				firstAssistant = assistantInfo;
				break;
			}
		}
	}

	let lastAssistant;

	for (let i = messages.length - 1; i >= 0; i--) {
		const msg = messages[i];
		if (msg.info.role === "assistant") {
			const assistantInfo = msg.info;
			if (assistantInfo.tokens?.output > 0) {
				lastAssistant = assistantInfo;
				break;
			}
		}
	}

	const apiInput = lastAssistant?.tokens?.input || 0,
		apiOutput = lastAssistant?.tokens?.output || 0,
		apiReasoning = lastAssistant?.tokens?.reasoning || 0,
		apiCacheRead = lastAssistant?.tokens?.cache?.read || 0,
		apiCacheWrite = lastAssistant?.tokens?.cache?.write || 0;

	breakdown.total = apiInput + apiOutput + apiReasoning + apiCacheRead + apiCacheWrite;

	const userTextParts = [],
		toolInputParts = [],
		toolOutputParts = [];

	let firstUserText = "",
		foundFirstUser = false;

	const allToolIds = new Set,
		activeToolIds = new Set,
		prunedByMessageToolIds = new Set,
		allMessageIds = new Set;

	for (const msg of messages) {
		allMessageIds.add(msg.info.id);

		const parts = Array.isArray(msg.parts) ? msg.parts : [],
			isCompacted = isMessageCompacted(state, msg),
			pruneEntry = state.prune.messages.byMessageId.get(msg.info.id),
			isMessagePruned = !!pruneEntry && pruneEntry.activeBlockIds.length > 0,
			isIgnoredUser = isIgnoredUserMessage(msg);

		for (const part of parts) {
			if (part.type === "tool") {
				const toolPart = part;

				if (toolPart.callID) {
					allToolIds.add(toolPart.callID);

					if (!isCompacted) {
						activeToolIds.add(toolPart.callID);
					}

					if (isMessagePruned) {
						prunedByMessageToolIds.add(toolPart.callID);
					}
				}

				const isPruned = toolPart.callID && state.prune.tools.has(toolPart.callID);

				if (!isCompacted && !isPruned) {
					if (toolPart.state?.input) {
						const inputStr = typeof toolPart.state.input === "string" ? toolPart.state.input : JSON.stringify(toolPart.state.input);

						toolInputParts.push(inputStr);
					}

					const outputStr = extractCompletedToolOutput(toolPart);

					if (outputStr !== undefined) {
						toolOutputParts.push(outputStr);
					}
				}
			} else if (part.type === "text" && msg.info.role === "user" && !isCompacted && !isIgnoredUser) {
				const textPart = part,
					text = textPart.text || "";

				userTextParts.push(text);

				if (!foundFirstUser) {
					firstUserText += text;
				}
			}
		}

		if (msg.info.role === "user" && !isIgnoredUser && !foundFirstUser) {
			foundFirstUser = true;
		}
	}

	const prunedByToolIds = new Set;

	for (const id of allToolIds) {
		if (state.prune.tools.has(id)) {
			prunedByToolIds.add(id);
		}
	}

	const prunedToolIds = new Set([...prunedByToolIds, ...prunedByMessageToolIds]),
		toolsInContextCount = [...activeToolIds].filter((id) => !prunedByToolIds.has(id)).length;

	let prunedMessageCount = 0;

	for (const [id, entry] of state.prune.messages.byMessageId) {
		if (allMessageIds.has(id) && entry.activeBlockIds.length > 0) {
			prunedMessageCount++;
		}
	}

	breakdown.toolCount = allToolIds.size;
	breakdown.toolsInContextCount = toolsInContextCount;
	breakdown.prunedToolCount = prunedToolIds.size;
	breakdown.prunedMessageCount = prunedMessageCount;

	const firstUserTokens = countTokens(firstUserText);

	breakdown.user = countTokens(userTextParts.join("\n"));

	const toolInputTokens = countTokens(toolInputParts.join("\n")),
		toolOutputTokens = countTokens(toolOutputParts.join("\n"));

	if (firstAssistant) {
		const firstInput = (firstAssistant.tokens?.input || 0) + (firstAssistant.tokens?.cache?.read || 0) + (firstAssistant.tokens?.cache?.write || 0);
		breakdown.system = Math.max(0, firstInput - firstUserTokens);
	}

	breakdown.tools = toolInputTokens + toolOutputTokens;
	breakdown.assistant = Math.max(0, breakdown.total - breakdown.system - breakdown.user - breakdown.tools);

	return breakdown;
}

function createBar(value, maxValue, width, char = "█") {
	if (maxValue === 0) {
		return "";
	}

	const filled = Math.round(value / maxValue * width),
		bar = char.repeat(Math.max(0, filled));

	return bar;
}

export function formatContextMessage(breakdown) {
	const lines = [],
		barWidth = 30,
		toolsLabel = `Tools (${breakdown.toolsInContextCount})`,
		categories = [
			{ label: "System", value: breakdown.system, char: "█" },
			{ label: "User", value: breakdown.user, char: "▓" },
			{ label: "Assistant", value: breakdown.assistant, char: "▒" },
			{ label: toolsLabel, value: breakdown.tools, char: "░" }
		],
		maxLabelLen = Math.max(...categories.map((c) => c.label.length));

	lines.push("╭───────────────────────────────────────────────────────────╮");
	lines.push("│                  DCP Context Analysis                     │");
	lines.push("╰───────────────────────────────────────────────────────────╯");
	lines.push("");
	lines.push("Session Context Breakdown:");
	lines.push("─".repeat(60));
	lines.push("");

	for (const cat of categories) {
		const bar = createBar(cat.value, breakdown.total, barWidth, cat.char),
			percentage = breakdown.total > 0 ? (cat.value / breakdown.total * 100).toFixed(1) : "0.0",
			labelWithPct = `${cat.label.padEnd(maxLabelLen)} ${percentage.padStart(5)}% `,
			valueStr = formatTokenCount(cat.value).padStart(13);

		lines.push(`${labelWithPct}│${bar.padEnd(barWidth)}│${valueStr}`);
	}

	lines.push("");
	lines.push("─".repeat(60));
	lines.push("");
	lines.push("Summary:");

	if (breakdown.prunedTokens > 0) {
		const withoutPruning = breakdown.total + breakdown.prunedTokens,
			pruned = [];

		if (breakdown.prunedToolCount > 0) {
			pruned.push(`${breakdown.prunedToolCount} tools`);
		}

		if (breakdown.prunedMessageCount > 0) {
			pruned.push(`${breakdown.prunedMessageCount} messages`);
		}

		lines.push(`  Pruned:          ${pruned.join(", ")} (~${formatTokenCount(breakdown.prunedTokens)})`);
		lines.push(`  Current context: ~${formatTokenCount(breakdown.total)}`);
		lines.push(`  Without DCP:     ~${formatTokenCount(withoutPruning)}`);
	} else {
		lines.push(`  Current context: ~${formatTokenCount(breakdown.total)}`);
	}

	lines.push("");

	return lines.join("\n");
}

export async function handleContextCommand(ctx) {
	const { client: client, state: state, logger: logger, sessionId: sessionId, messages: messages } = ctx;

	const breakdown = analyzeContextTokens(state, messages),
		message = formatContextMessage(breakdown),
		params = getCurrentParams(state, messages, logger);

	await sendIgnoredMessage(client, sessionId, message, params, logger);
}
