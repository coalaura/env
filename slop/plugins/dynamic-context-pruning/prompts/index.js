export function renderSystemPrompt(prompts, protectedToolsExtension, manual, subagent) {
	const extensions = [];

	if (protectedToolsExtension) {
		extensions.push(protectedToolsExtension.trim());
	}

	if (manual) {
		extensions.push(prompts.manualExtension.trim());
	}

	if (subagent) {
		extensions.push(prompts.subagentExtension.trim());
	}

	return [prompts.system.trim(), ...extensions].filter(Boolean).join("\n\n").replace(/\n([ \t]*\n)+/g, "\n\n").trim();
}
