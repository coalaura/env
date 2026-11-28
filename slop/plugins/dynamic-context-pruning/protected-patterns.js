function normalizePath(input) {
	return input.replaceAll("\\", "/");
}

function escapeRegExpChar(ch) {
	return /[\\.^$+{}()|\[\]]/.test(ch) ? `\\${ch}` : ch;
}

export function matchesGlob(inputPath, pattern) {
	if (!pattern) {
		return false;
	}

	const input = normalizePath(inputPath),
		pat = normalizePath(pattern);

	let regex = "^";

	for (let i = 0; i < pat.length; i++) {
		const ch = pat[i];

		if (ch === "*") {
			const next = pat[i + 1];

			if (next === "*") {
				const after = pat[i + 2];

				if (after === "/") {
					regex += "(?:.*/)?";
					i += 2;

					continue;
				}

				regex += ".*";
				i++;

				continue;
			}

			regex += "[^/]*";

			continue;
		}

		if (ch === "?") {
			regex += "[^/]";

			continue;
		}

		if (ch === "/") {
			regex += "/";

			continue;
		}

		regex += escapeRegExpChar(ch);
	}

	regex += "$";

	return new RegExp(regex).test(input);
}

export function getFilePathsFromParameters(tool, parameters) {
	if (typeof parameters !== "object" || parameters === null) {
		return [];
	}

	const paths = [],
		params = parameters;

	if ((tool === "apply_patch" || tool === "patch") && typeof params.patchText === "string") {
		const pathRegex = /\*\*\* (?:Add|Delete|Update) File: ([^\n\r]+)/g;

		let match;

		while ((match = pathRegex.exec(params.patchText)) !== null) {
			paths.push(match[1].trim());
		}
	}

	if (tool === "multiedit") {
		if (typeof params.filePath === "string") {
			paths.push(params.filePath);
		}

		if (Array.isArray(params.edits)) {
			for (const edit of params.edits) {
				if (edit && typeof edit.filePath === "string") {
					paths.push(edit.filePath);
				}
			}
		}
	}

	if (typeof params.filePath === "string") {
		paths.push(params.filePath);
	}

	if (["read", "write", "edit"].includes(tool) && typeof params.path === "string") {
		paths.push(params.path);
	}

	return [...new Set(paths)].filter((p) => p.length > 0);
}

export function isFilePathProtected(filePaths, patterns) {
	if (!filePaths || filePaths.length === 0) {
		return false;
	}

	if (!patterns || patterns.length === 0) {
		return false;
	}

	return filePaths.some((path) => patterns.some((pattern) => matchesGlob(path, pattern)));
}

const GLOB_CHARS = /[*?]/;

export function isToolNameProtected(toolName, patterns) {
	if (!toolName || !patterns || patterns.length === 0) {
		return false;
	}

	const exactPatterns = new Set,
		globPatterns = [];

	for (const pattern of patterns) {
		if (GLOB_CHARS.test(pattern)) {
			globPatterns.push(pattern);
		} else {
			exactPatterns.add(pattern);
		}
	}

	if (exactPatterns.has(toolName)) {
		return true;
	}

	return globPatterns.some((pattern) => matchesGlob(toolName, pattern));
}

export function isToolProtected(tool, input, tools, files, metadata) {
	const calls = [{ tool: tool, input: input }];

	if (tool === "execute" && Array.isArray(metadata?.toolCalls)) {
		for (const call of metadata.toolCalls) {
			if (call && typeof call.tool === "string") {
				calls.push(call);
			}
		}
	}

	return calls.some((call) => isToolNameProtected(call.tool, tools) || isFilePathProtected(getFilePathsFromParameters(call.tool, call.input), files));
}
