import { readFileSync } from "node:fs";
import { join } from "node:path";
import { configDirectories } from "../paths.js";
import { systemPrompt } from "./system.js";
import { rangePrompt } from "./compress-range.js";
import { messagePrompt } from "./compress-message.js";
import { CONTEXT_LIMIT_NUDGE } from "./context-limit-nudge.js";
import { TURN_NUDGE } from "./turn-nudge.js";
import { ITERATION_NUDGE } from "./iteration-nudge.js";
import { MANUAL_MODE_SYSTEM_EXTENSION, SUBAGENT_SYSTEM_EXTENSION } from "./extensions/system.js";

const PROMPT_FIELDS = {
	system: "system",
	"compress-range": "compressRange",
	"compress-message": "compressMessage",
	"context-limit-nudge": "contextLimitNudge",
	"turn-nudge": "turnNudge",
	"iteration-nudge": "iterationNudge"
};

export class PromptStore {
	constructor(logger, workingDirectory, customPromptsEnabled = false, idFormat = "xml") {
		this.logger = logger;
		this.directories = customPromptsEnabled ? configDirectories(workingDirectory).reverse() : [];
		this.bundled = Object.freeze({
			system: systemPrompt(idFormat),
			compressRange: rangePrompt(idFormat),
			compressMessage: messagePrompt(idFormat),
			contextLimitNudge: CONTEXT_LIMIT_NUDGE,
			turnNudge: TURN_NUDGE,
			iterationNudge: ITERATION_NUDGE,
			manualExtension: MANUAL_MODE_SYSTEM_EXTENSION,
			subagentExtension: SUBAGENT_SYSTEM_EXTENSION
		});

		this.runtimePrompts = this.bundled;

		this.reload();
	}

	getRuntimePrompts() {
		return this.runtimePrompts;
	}

	reload() {
		if (!this.directories.length) {
			return;
		}

		const prompts = { ...this.bundled };

		for (const [key, field] of Object.entries(PROMPT_FIELDS)) {
			prompts[field] = normalizePrompt(key, this.bundled[field]) || this.bundled[field].trim();

			for (const directory of this.directories) {
				const path = join(directory, "dcp-prompts", "overrides", `${key}.md`);

				let content;

				try {
					content = readFileSync(path, "utf8");
				} catch {
					continue;
				}

				const normalized = normalizePrompt(key, content);

				if (!normalized) {
					this.logger.warn("Prompt override is empty or invalid after normalization", { key: key, path: path });

					continue;
				}

				prompts[field] = normalized;

				break;
			}
		}

		this.runtimePrompts = Object.freeze(prompts);
	}
}

function normalizePrompt(key, content) {
	let text = content.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").replace(/<!--[\s\S]*?-->/g, "").replace(/^[ \t]*\/\/.*?\/\/[ \t]*$/gm, "").trim();

	if (key === "system") {
		text = text.replace(/<manual>[\s\S]*?<\/manual>/gi, "").replace(/<subagent>[\s\S]*?<\/subagent>/gi, "").trim();
	}

	if (key === "compress-range" || key === "compress-message") {
		return text;
	}

	const opening = /^\s*<dcp-system-reminder\b[^>]*>\s*/i,
		closing = /\s*<\/dcp-system-reminder>\s*$/i;

	if (opening.test(text) !== closing.test(text)) {
		return "";
	}

	text = text.replace(opening, "").replace(closing, "").trim();

	return text ? `<dcp-system-reminder>\n${text}\n</dcp-system-reminder>` : "";
}
