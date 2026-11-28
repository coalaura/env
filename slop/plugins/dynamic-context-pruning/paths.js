import { statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

export function configDirectories(workingDirectory) {
	let project = null,
		current = workingDirectory;

	while (current) {
		const candidate = join(current, ".opencode");

		if (statSync(candidate, { throwIfNoEntry: false })?.isDirectory()) {
			project = candidate;

			break;
		}

		const parent = dirname(current);

		if (parent === current) {
			break;
		}

		current = parent;
	}

	return [join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"), "opencode"), process.env.OPENCODE_CONFIG_DIR || null, project].filter(Boolean);
}
