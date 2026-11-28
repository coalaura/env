import { resolveAnchorMessageId, resolveBoundaryIds, resolveSelection } from "./search.js";

const BLOCK_PLACEHOLDER_REGEX = /\(b(\d+)\)|\{block_(\d+)\}/gi;

export function validateArgs(args) {
	if (typeof args.topic !== "string" || args.topic.trim().length === 0) {
		throw new Error("topic is required and must be a non-empty string");
	}

	if (!Array.isArray(args.content) || args.content.length === 0) {
		throw new Error("content is required and must be a non-empty array");
	}

	for (let index = 0; index < args.content.length; index++) {
		const entry = args.content[index],
			prefix = `content[${index}]`;

		if (typeof entry?.startId !== "string" || entry.startId.trim().length === 0) {
			throw new Error(`${prefix}.startId is required and must be a non-empty string`);
		}

		if (typeof entry?.endId !== "string" || entry.endId.trim().length === 0) {
			throw new Error(`${prefix}.endId is required and must be a non-empty string`);
		}

		if (typeof entry?.summary !== "string" || entry.summary.trim().length === 0) {
			throw new Error(`${prefix}.summary is required and must be a non-empty string`);
		}
	}
}

export function resolveRanges(args, searchContext, state) {
	return args.content.map((entry, index) => {
		const normalizedEntry = {
			startId: entry.startId.trim(),
			endId: entry.endId.trim(),
			summary: entry.summary
		};

		const { startReference: startReference, endReference: endReference } = resolveBoundaryIds(searchContext, state, normalizedEntry.startId, normalizedEntry.endId),
			selection = resolveSelection(searchContext, startReference, endReference);

		return {
			index: index,
			entry: normalizedEntry,
			selection: selection,
			anchorMessageId: resolveAnchorMessageId(startReference)
		};
	});
}

export function validateNonOverlapping(plans) {
	const sortedPlans = [...plans].sort((left, right) => left.selection.startReference.rawIndex - right.selection.startReference.rawIndex || left.selection.endReference.rawIndex - right.selection.endReference.rawIndex || left.index - right.index),
		issues = [];

	for (let index = 1; index < sortedPlans.length; index++) {
		const previous = sortedPlans[index - 1],
			current = sortedPlans[index];

		if (!previous || !current) {
			continue;
		}

		if (current.selection.startReference.rawIndex > previous.selection.endReference.rawIndex) {
			continue;
		}

		issues.push(`content[${previous.index}] (${previous.entry.startId}..${previous.entry.endId}) overlaps content[${current.index}] (${current.entry.startId}..${current.entry.endId}). Overlapping ranges cannot be compressed in the same batch.`);
	}

	if (issues.length > 0) {
		throw new Error(issues.length === 1 ? issues[0] : issues.map((issue) => `- ${issue}`).join("\n"));
	}
}

export function parseBlockPlaceholders(summary, format = "xml") {
	const placeholders = [],
		regex = format === "compact" ? /@b([1-9]\d*)@/gi : new RegExp(BLOCK_PLACEHOLDER_REGEX);

	let match;

	while ((match = regex.exec(summary)) !== null) {
		const full = match[0],
			blockIdPart = match[1] || match[2],
			parsed = Number.parseInt(blockIdPart, 10);

		if (!Number.isInteger(parsed)) {
			continue;
		}

		placeholders.push({
			raw: full,
			blockId: parsed,
			startIndex: match.index,
			endIndex: match.index + full.length
		});
	}

	return placeholders;
}

export function validateSummaryPlaceholders(placeholders, requiredBlockIds, startReference, endReference, summaryByBlockId) {
	const boundaryOptionalIds = new Set;

	if (startReference.kind === "compressed-block") {
		if (startReference.blockId === undefined) {
			throw new Error("Failed to map boundary matches back to raw messages");
		}

		boundaryOptionalIds.add(startReference.blockId);
	}

	if (endReference.kind === "compressed-block") {
		if (endReference.blockId === undefined) {
			throw new Error("Failed to map boundary matches back to raw messages");
		}

		boundaryOptionalIds.add(endReference.blockId);
	}

	const strictRequiredIds = requiredBlockIds.filter((id) => !boundaryOptionalIds.has(id)),
		requiredSet = new Set(requiredBlockIds),
		keptPlaceholderIds = new Set,
		validPlaceholders = [];

	for (const placeholder of placeholders) {
		const isKnown = summaryByBlockId.has(placeholder.blockId),
			isRequired = requiredSet.has(placeholder.blockId),
			isDuplicate = keptPlaceholderIds.has(placeholder.blockId);

		if (isKnown && isRequired && !isDuplicate) {
			validPlaceholders.push(placeholder);
			keptPlaceholderIds.add(placeholder.blockId);
		}
	}

	placeholders.length = 0;
	placeholders.push(...validPlaceholders);

	return strictRequiredIds.filter((id) => !keptPlaceholderIds.has(id));
}

export function injectBlockPlaceholders(summary, placeholders, summaryByBlockId, startReference, endReference) {
	let cursor = 0,
		expanded = summary;

	const consumed = [],
		consumedSeen = new Set;

	if (placeholders.length > 0) {
		expanded = "";

		for (const placeholder of placeholders) {
			const target = summaryByBlockId.get(placeholder.blockId);

			if (!target) {
				throw new Error(`Compressed block not found: (b${placeholder.blockId})`);
			}

			expanded += summary.slice(cursor, placeholder.startIndex);
			expanded += restoreSummary(target.summary);

			cursor = placeholder.endIndex;

			if (!consumedSeen.has(placeholder.blockId)) {
				consumedSeen.add(placeholder.blockId);
				consumed.push(placeholder.blockId);
			}
		}

		expanded += summary.slice(cursor);
	}

	expanded = injectBoundarySummary(expanded, startReference, "start", summaryByBlockId, consumed, consumedSeen);
	expanded = injectBoundarySummary(expanded, endReference, "end", summaryByBlockId, consumed, consumedSeen);

	return {
		expandedSummary: expanded,
		consumedBlockIds: consumed
	};
}

export function appendMissingBlockSummaries(summary, missingBlockIds, summaryByBlockId, consumedBlockIds, format = "xml") {
	const consumedSeen = new Set(consumedBlockIds),
		consumed = [...consumedBlockIds],
		missingSummaries = [];

	for (const blockId of missingBlockIds) {
		if (consumedSeen.has(blockId)) {
			continue;
		}

		const target = summaryByBlockId.get(blockId);

		if (!target) {
			throw new Error(`Compressed block not found: (b${blockId})`);
		}

		const label = format === "compact" ? `compressed block ${blockId}` : `(b${blockId})`;

		missingSummaries.push(`
### ${label}
${restoreSummary(target.summary)}`);

		consumedSeen.add(blockId);
		consumed.push(blockId);
	}

	if (missingSummaries.length === 0) {
		return {
			expandedSummary: summary,
			consumedBlockIds: consumed
		};
	}

	const heading = `

The following previously compressed summaries were also part of this conversation section:`;

	return {
		expandedSummary: summary + heading + missingSummaries.join(""),
		consumedBlockIds: consumed
	};
}

function restoreSummary(summary) {
	const headerMatch = summary.match(/^\s*\[Compressed conversation(?: section)?(?: b\d+)?\]/i);

	if (!headerMatch) {
		return summary;
	}

	const afterHeader = summary.slice(headerMatch[0].length),
		withoutLeadingBreaks = afterHeader.replace(/^(?:\r?\n)+/, "");

	return withoutLeadingBreaks.replace(/(?:\r?\n)*<dcp-message-id>b\d+<\/dcp-message-id>\s*$/i, "").replace(/(?:\r?\n)*@b[1-9]\d*@\s*$/i, "").replace(/(?:\r?\n)+$/, "");
}

function injectBoundarySummary(summary, reference, position, summaryByBlockId, consumed, consumedSeen) {
	if (reference.kind !== "compressed-block" || reference.blockId === undefined) {
		return summary;
	}

	if (consumedSeen.has(reference.blockId)) {
		return summary;
	}

	const target = summaryByBlockId.get(reference.blockId);

	if (!target) {
		throw new Error(`Compressed block not found: (b${reference.blockId})`);
	}

	const injectedBody = restoreSummary(target.summary),
		left = position === "start" ? injectedBody.trim() : summary.trim(),
		right = position === "start" ? summary.trim() : injectedBody.trim(),
		next = !left ? right : !right ? left : `${left}

${right}`;

	consumedSeen.add(reference.blockId);
	consumed.push(reference.blockId);

	return next;
}
