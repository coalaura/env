import { isMessageCompacted } from "./utils.js";
import { countToolTokens } from "../token-utils.js";

const MAX_TOOL_CACHE_SIZE = 1000;

export function syncToolCache(state, config, logger, messages) {
	try {
		logger.info("Syncing tool parameters from OpenCode messages");

		let turnCounter = 0;

		for (const msg of messages) {
			if (isMessageCompacted(state, msg)) {
				continue;
			}

			const parts = Array.isArray(msg.parts) ? msg.parts : [];

			for (const part of parts) {
				if (part.type === "step-start") {
					turnCounter++;

					continue;
				}

				if (part.type !== "tool" || !part.callID) {
					continue;
				}

				const turnProtectionEnabled = config.turnProtection.enabled,
					turnProtectionTurns = config.turnProtection.turns,
					isProtectedByTurn = turnProtectionEnabled && turnProtectionTurns > 0 && state.currentTurn - turnCounter < turnProtectionTurns;

				if (state.toolParameters.has(part.callID)) {
					continue;
				}

				if (isProtectedByTurn) {
					continue;
				}

				const tokenCount = countToolTokens(part);

				state.toolParameters.set(part.callID, {
					tool: part.tool,
					parameters: part.state?.input ?? {},
					metadata: "metadata" in part.state ? part.state.metadata : undefined,
					status: part.state.status,
					error: part.state.status === "error" ? part.state.error : undefined,
					turn: turnCounter,
					tokenCount: tokenCount
				});

				logger.info(`Cached tool id: ${part.callID} (turn ${turnCounter}${tokenCount !== undefined ? `, ${tokenCount} tokens` : ""})`);
			}
		}

		logger.info(`Synced cache - size: ${state.toolParameters.size}, currentTurn: ${state.currentTurn}`);

		trimToolParametersCache(state);
	} catch (error) {
		logger.warn("Failed to sync tool parameters from OpenCode", {
			error: error instanceof Error ? error.message : String(error)
		});
	}
}

export function trimToolParametersCache(state) {
	if (state.toolParameters.size <= MAX_TOOL_CACHE_SIZE) {
		return;
	}

	const keysToRemove = Array.from(state.toolParameters.keys()).slice(0, state.toolParameters.size - MAX_TOOL_CACHE_SIZE);

	for (const key of keysToRemove) {
		state.toolParameters.delete(key);
	}
}
