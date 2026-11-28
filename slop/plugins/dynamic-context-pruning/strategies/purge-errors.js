import { isToolProtected } from "../protected-patterns.js";
import { getTotalToolTokens } from "../token-utils.js";

export const purgeErrors = (state, logger, config, messages) => {
	if (state.manualMode && !config.manualMode.automaticStrategies) {
		return;
	}

	if (!config.strategies.purgeErrors.enabled) {
		return;
	}

	const allToolIds = state.toolIdList;

	if (allToolIds.length === 0) {
		return;
	}

	const unprunedIds = allToolIds.filter((id) => !state.prune.tools.has(id));

	if (unprunedIds.length === 0) {
		return;
	}

	const protectedTools = config.strategies.purgeErrors.protectedTools,
		turnThreshold = Math.max(1, config.strategies.purgeErrors.turns),
		newPruneIds = [];

	for (const id of unprunedIds) {
		const metadata = state.toolParameters.get(id);

		if (!metadata) {
			continue;
		}

		if (isToolProtected(metadata.tool, metadata.parameters, protectedTools, config.protectedFilePatterns, metadata.metadata)) {
			continue;
		}

		if (metadata.status !== "error") {
			continue;
		}

		const turnAge = state.currentTurn - metadata.turn;

		if (turnAge >= turnThreshold) {
			newPruneIds.push(id);
		}
	}

	if (newPruneIds.length > 0) {
		state.stats.totalPruneTokens += getTotalToolTokens(state, newPruneIds);

		for (const id of newPruneIds) {
			const entry = state.toolParameters.get(id);

			state.prune.tools.set(id, entry?.tokenCount ?? 0);
		}

		logger.debug(`Marked ${newPruneIds.length} error tool calls for pruning (older than ${turnThreshold} turns)`);
	}
};
