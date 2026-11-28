import { isToolProtected } from "../protected-patterns.js";
import { getTotalToolTokens } from "../token-utils.js";

export const deduplicate = (state, logger, config, messages) => {
	if (state.manualMode && !config.manualMode.automaticStrategies) {
		return;
	}

	if (!config.strategies.deduplication.enabled) {
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

	const protectedTools = config.strategies.deduplication.protectedTools,
		signatureMap = new Map;

	for (const id of unprunedIds) {
		const metadata = state.toolParameters.get(id);

		if (!metadata) {
			continue;
		}

		if (isToolProtected(metadata.tool, metadata.parameters, protectedTools, config.protectedFilePatterns, metadata.metadata)) {
			continue;
		}

		const signature = createToolSignature(metadata.tool, metadata.parameters);

		if (!signatureMap.has(signature)) {
			signatureMap.set(signature, []);
		}

		const ids = signatureMap.get(signature);

		if (ids) {
			ids.push(id);
		}
	}

	const newPruneIds = [];

	for (const [, ids] of signatureMap.entries()) {
		if (ids.length > 1) {
			const idsToRemove = ids.slice(0, -1);

			newPruneIds.push(...idsToRemove);
		}
	}

	state.stats.totalPruneTokens += getTotalToolTokens(state, newPruneIds);

	if (newPruneIds.length > 0) {
		for (const id of newPruneIds) {
			const entry = state.toolParameters.get(id);

			state.prune.tools.set(id, entry?.tokenCount ?? 0);
		}

		logger.debug(`Marked ${newPruneIds.length} duplicate tool calls for pruning`);
	}
};

function createToolSignature(tool, parameters) {
	if (!parameters) {
		return tool;
	}

	const normalized = normalizeParameters(parameters),
		sorted = sortObjectKeys(normalized);

	return `${tool}::${JSON.stringify(sorted)}`;
}

function normalizeParameters(params) {
	if (typeof params !== "object" || params === null) {
		return params;
	}

	if (Array.isArray(params)) {
		return params;
	}

	const normalized = {};

	for (const [key, value] of Object.entries(params)) {
		if (value !== undefined && value !== null) {
			normalized[key] = value;
		}
	}

	return normalized;
}

function sortObjectKeys(obj) {
	if (typeof obj !== "object" || obj === null) {
		return obj;
	}

	if (Array.isArray(obj)) {
		return obj.map(sortObjectKeys);
	}

	const sorted = {};

	for (const key of Object.keys(obj).sort()) {
		sorted[key] = sortObjectKeys(obj[key]);
	}

	return sorted;
}
