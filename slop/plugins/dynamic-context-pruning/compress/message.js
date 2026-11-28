import { countTokens } from "../token-utils.js";
import { messageFormat } from "../prompts/extensions/tool.js";
import { formatMessageRef } from "../message-ids.js";
import { formatIssues, formatResult, resolveMessages, validateArgs } from "./message-utils.js";
import { finalizeSession, prepareSession } from "./pipeline.js";
import { appendProtectedPromptInfo, appendProtectedTools } from "./protected-content.js";
import {
	allocateBlockId,
	allocateRunId,
	applyCompressionState,
	wrapCompressedSummary
} from "./state.js";

function buildSchema(format) {
	return {
		topic: {
			type: "string",
			description: "Short label (3-5 words) for the overall batch - e.g., 'Closed Research Notes'"
		},
		content: {
			type: "array",
			description: "Batch of individual message summaries to create in one tool call",
			items: {
				type: "object",
				properties: {
					messageId: {
						type: "string",
						description: `Raw message ID to compress (e.g. ${formatMessageRef(1, format)})`
					},
					topic: {
						type: "string",
						description: "Short label (3-5 words) for this one message summary"
					},
					summary: {
						type: "string",
						description: "Complete technical summary replacing that one message"
					}
				},
				required: ["messageId", "topic", "summary"],
				additionalProperties: false
			}
		}
	};
}

export function createCompressMessageTool(ctx) {
	ctx.prompts.reload();

	const runtimePrompts = ctx.prompts.getRuntimePrompts();

	return {
		description: `${runtimePrompts.compressMessage}${messageFormat(ctx.state.idFormat)}`,
		args: buildSchema(ctx.state.idFormat),
		async execute(args, toolCtx) {
			const input = args;

			validateArgs(input);

			const callId = typeof toolCtx.callID === "string" ? toolCtx.callID : undefined;

			const { rawMessages: rawMessages, searchContext: searchContext } = await prepareSession(ctx, toolCtx, `Compress Message: ${input.topic}`),
				{ plans: plans, skippedIssues: skippedIssues, skippedCount: skippedCount } = resolveMessages(input, searchContext, ctx.state, ctx.config);

			if (plans.length === 0 && skippedCount > 0) {
				throw new Error(formatIssues(skippedIssues, skippedCount));
			}

			const notifications = [],
				preparedPlans = [];

			for (const plan of plans) {
				const summaryWithPromptInfo = appendProtectedPromptInfo(plan.entry.summary, plan.selection, searchContext, ctx.state, ctx.config.compress.protectTags),
					summaryWithTools = await appendProtectedTools(ctx.client, ctx.state, ctx.config.experimental.allowSubAgents, summaryWithPromptInfo, plan.selection, searchContext, ctx.config.compress.protectedTools, ctx.config.protectedFilePatterns);

				preparedPlans.push({
					plan: plan,
					summaryWithTools: summaryWithTools
				});
			}

			const runId = allocateRunId(ctx.state);

			for (const { plan: plan, summaryWithTools: summaryWithTools } of preparedPlans) {
				const blockId = allocateBlockId(ctx.state),
					storedSummary = wrapCompressedSummary(blockId, summaryWithTools, ctx.state.idFormat),
					summaryTokens = countTokens(storedSummary);

				applyCompressionState(ctx.state, {
					topic: plan.entry.topic,
					batchTopic: input.topic,
					startId: plan.entry.messageId,
					endId: plan.entry.messageId,
					mode: "message",
					runId: runId,
					compressMessageId: toolCtx.messageID,
					compressCallId: callId,
					summaryTokens: summaryTokens
				}, plan.selection, plan.anchorMessageId, blockId, storedSummary, []);

				notifications.push({
					blockId: blockId,
					runId: runId,
					summary: summaryWithTools,
					summaryTokens: summaryTokens
				});
			}

			await finalizeSession(ctx, toolCtx, rawMessages, notifications, input.topic);

			return formatResult(plans.length, skippedIssues, skippedCount);
		}
	};
}
