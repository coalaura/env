import { countTokens } from "../token-utils.js";
import { rangeFormat } from "../prompts/extensions/tool.js";
import { formatMessageRef, formatBlockRef } from "../message-ids.js";
import { finalizeSession, prepareSession } from "./pipeline.js";
import {
	appendProtectedPromptInfo,
	appendProtectedTools,
	appendProtectedUserMessages
} from "./protected-content.js";
import {
	appendMissingBlockSummaries,
	injectBlockPlaceholders,
	parseBlockPlaceholders,
	resolveRanges,
	validateArgs,
	validateNonOverlapping,
	validateSummaryPlaceholders
} from "./range-utils.js";
import {
	COMPRESSED_BLOCK_HEADER,
	allocateBlockId,
	allocateRunId,
	applyCompressionState,
	wrapCompressedSummary
} from "./state.js";

function buildSchema(format) {
	return {
		topic: {
			type: "string",
			description: "Short label (3-5 words) for display - e.g., 'Auth System Exploration'"
		},
		content: {
			type: "array",
			description: "One or more ranges to compress, each with start/end boundaries and a summary",
			items: {
				type: "object",
				properties: {
					startId: {
						type: "string",
						description: `Message or block ID marking the beginning of range (e.g. ${formatMessageRef(1, format)}, ${formatBlockRef(2, format)})`
					},
					endId: {
						type: "string",
						description: `Message or block ID marking the end of range (e.g. ${formatMessageRef(12, format)}, ${formatBlockRef(5, format)})`
					},
					summary: {
						type: "string",
						description: "Complete technical summary replacing all content in range"
					}
				},
				required: ["startId", "endId", "summary"],
				additionalProperties: false
			}
		}
	};
}

export function createCompressRangeTool(ctx) {
	ctx.prompts.reload();

	const runtimePrompts = ctx.prompts.getRuntimePrompts();

	return {
		description: `${runtimePrompts.compressRange}${rangeFormat(ctx.state.idFormat)}`,
		args: buildSchema(ctx.state.idFormat),
		async execute(args, toolCtx) {
			const input = args;

			validateArgs(input);

			const callId = typeof toolCtx.callID === "string" ? toolCtx.callID : undefined,
				{ rawMessages: rawMessages, searchContext: searchContext } = await prepareSession(ctx, toolCtx, `Compress Range: ${input.topic}`),
				resolvedPlans = resolveRanges(input, searchContext, ctx.state);

			validateNonOverlapping(resolvedPlans);

			const notifications = [],
				preparedPlans = [];

			let totalCompressedMessages = 0;

			for (const plan of resolvedPlans) {
				const parsedPlaceholders = parseBlockPlaceholders(plan.entry.summary, ctx.state.idFormat),
					missingBlockIds = validateSummaryPlaceholders(parsedPlaceholders, plan.selection.requiredBlockIds, plan.selection.startReference, plan.selection.endReference, searchContext.summaryByBlockId),
					injected = injectBlockPlaceholders(plan.entry.summary, parsedPlaceholders, searchContext.summaryByBlockId, plan.selection.startReference, plan.selection.endReference),
					summaryWithUsers = appendProtectedUserMessages(injected.expandedSummary, plan.selection, searchContext, ctx.state, ctx.config.compress.protectUserMessages),
					summaryWithPromptInfo = appendProtectedPromptInfo(summaryWithUsers, plan.selection, searchContext, ctx.state, ctx.config.compress.protectTags),
					summaryWithTools = await appendProtectedTools(ctx.client, ctx.state, ctx.config.experimental.allowSubAgents, summaryWithPromptInfo, plan.selection, searchContext, ctx.config.compress.protectedTools, ctx.config.protectedFilePatterns),
					completedSummary = appendMissingBlockSummaries(summaryWithTools, missingBlockIds, searchContext.summaryByBlockId, injected.consumedBlockIds, ctx.state.idFormat);

				preparedPlans.push({
					entry: plan.entry,
					selection: plan.selection,
					anchorMessageId: plan.anchorMessageId,
					finalSummary: completedSummary.expandedSummary,
					consumedBlockIds: completedSummary.consumedBlockIds
				});
			}

			const runId = allocateRunId(ctx.state);

			for (const preparedPlan of preparedPlans) {
				const blockId = allocateBlockId(ctx.state),
					storedSummary = wrapCompressedSummary(blockId, preparedPlan.finalSummary, ctx.state.idFormat),
					summaryTokens = countTokens(storedSummary);

				const applied = applyCompressionState(ctx.state, {
					topic: input.topic,
					batchTopic: input.topic,
					startId: preparedPlan.entry.startId,
					endId: preparedPlan.entry.endId,
					mode: "range",
					runId: runId,
					compressMessageId: toolCtx.messageID,
					compressCallId: callId,
					summaryTokens: summaryTokens
				}, preparedPlan.selection, preparedPlan.anchorMessageId, blockId, storedSummary, preparedPlan.consumedBlockIds);

				totalCompressedMessages += applied.messageIds.length;

				notifications.push({
					blockId: blockId,
					runId: runId,
					summary: preparedPlan.finalSummary,
					summaryTokens: summaryTokens
				});
			}

			await finalizeSession(ctx, toolCtx, rawMessages, notifications, input.topic);

			return `Compressed ${totalCompressedMessages} messages into ${COMPRESSED_BLOCK_HEADER}.`;
		}
	};
}
