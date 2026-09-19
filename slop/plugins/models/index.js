import { Plugin } from "@opencode/plugin";

const allowedModels = {
	openai: new Set([
		"gpt-5.6-luna",
		"gpt-5.6-sol",
		"gpt-5.6-terra",
		"gpt-6-astra",
	]),

	openrouter: new Set([
		"deepseek/deepseek-v4.1-flash",
		"google/gemini-3.8-flash",
		"inception/mercury-2.5-preview",
		"openai/gpt-5.6-luna",
		"openai/gpt-5.6-sol-flex",
		"openai/gpt-5.6-terra",
		"openai/gpt-6-astra-flex",
		"x-ai/grok-4.6",
		"z-ai/glm-5.3-flash",
		"z-ai/glm-5.3",
	]),
};

export default Plugin.define({
	id: "coalaura.model-filter",

	async setup(ctx) {
		await ctx.model.transform(editor => {
			for (const model of editor.list()) {
				const models = allowedModels[model.providerID];

				if (models && !models.has(model.id)) {
					editor.remove(model.providerID, model.id);
				}
			}
		})
	},
});
