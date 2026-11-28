import { formatBlockRef } from "../../message-ids.js";

export function buildCompressedBlockGuidance(state) {
	const refs = Array.from(state.prune.messages.activeBlockIds).filter((id) => Number.isInteger(id) && id > 0).sort((a, b) => a - b).map((id) => formatBlockRef(id, state.idFormat)),
		blockCount = refs.length,
		blockList = blockCount > 0 ? refs.join(", ") : "none";

	return [
		"Compressed block context:",
		`- Active compressed blocks in this session: ${blockCount} (${blockList})`,
		`- If your selected compression range includes any listed block, include each required placeholder exactly once in the summary using \`${state.idFormat === "compact" ? "@b1@" : "(bN)"}\`.`
	].join("\n");
}

export function renderMessagePriorityGuidance(priorityLabel, refs) {
	const refList = refs.length > 0 ? refs.join(", ") : "none";

	return [
		"Message priority context:",
		"- Higher-priority older messages consume more context and should be compressed right away if it is safe to do so.",
		`- ${priorityLabel}-priority message IDs before this point: ${refList}`
	].join("\n");
}

export function appendGuidanceToDcpTag(nudgeText, guidance) {
	if (!guidance.trim()) {
		return nudgeText;
	}

	const closeTag = "</dcp-system-reminder>",
		closeTagIndex = nudgeText.lastIndexOf(closeTag);

	if (closeTagIndex === -1) {
		return nudgeText;
	}

	const beforeClose = nudgeText.slice(0, closeTagIndex).trimEnd(),
		afterClose = nudgeText.slice(closeTagIndex);

	return `${beforeClose}

${guidance}
${afterClose}`;
}
