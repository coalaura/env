import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { configDirectories } from "./paths.js";

const DEFAULTS = {
	enabled: true,
	debug: false,
	pruneNotification: "minimal",
	pruneNotificationType: "toast",
	commands: {
		enabled: true,
		protectedTools: ["task", "skill", "todowrite", "todoread", "compress", "batch", "plan_enter", "plan_exit", "write", "edit"]
	},
	manualMode: {
		enabled: false,
		automaticStrategies: true
	},
	turnProtection: {
		enabled: true,
		turns: 2
	},
	experimental: {
		allowSubAgents: false,
		customPrompts: false
	},
	protectedFilePatterns: [],
	compress: {
		mode: "range",
		permission: "allow",
		showCompression: true,
		summaryBuffer: true,
		maxContextLimit: 85000,
		minContextLimit: 50000,
		modelMaxLimits: {},
		modelMinLimits: {},
		nudgeFrequency: 5,
		iterationNudgeThreshold: 12,
		nudgeForce: "soft",
		protectedTools: ["task", "skill", "todowrite", "todoread"],
		protectTags: false,
		protectUserMessages: true
	},
	strategies: {
		deduplication: {
			enabled: true,
			protectedTools: []
		},
		purgeErrors: {
			enabled: true,
			turns: 3,
			protectedTools: []
		}
	}
};

const CHOICES = {
	pruneNotification: ["off", "minimal", "detailed"],
	pruneNotificationType: ["chat", "toast"],
	"compress.mode": ["range", "message"],
	"compress.permission": ["ask", "allow", "deny"],
	"compress.nudgeForce": ["strong", "soft"]
};

const LIMITS = new Set(["compress.minContextLimit", "compress.maxContextLimit"]),
	MODEL_LIMITS = new Set(["compress.modelMinLimits", "compress.modelMaxLimits"]),
	POSITIVE = new Set(["turnProtection.turns", "compress.nudgeFrequency", "compress.iterationNudgeThreshold", "strategies.purgeErrors.turns"]),
	LEGACY_KEYS = new Set(["$schema", "autoUpdate", "showUpdateToasts"]);

export function getConfig(context) {
	const config = structuredClone(DEFAULTS);

	for (const directory of configDirectories(context?.directory)) {
		const path = ["dcp.jsonc", "dcp.json"].map((name) => join(directory, name)).find(existsSync);

		if (!path) {
			continue;
		}

		const warnings = [];

		try {
			const data = Bun.JSONC.parse(readFileSync(path, "utf8"));

			mergeConfig(config, data, warnings);
		} catch (error) {
			warnings.push(`${error.message}\nUsing previous/default values`);
		}

		if (warnings.length) {
			scheduleWarning(context, path, warnings);
		}
	}

	return config;
}

export function mergeConfig(base, override, warnings = [], prefix = "") {
	if (!isObject(override)) {
		warnings.push(`${prefix || "config"}: expected object`);

		return;
	}

	for (const [key, value] of Object.entries(override)) {
		const path = prefix ? `${prefix}.${key}` : key;

		if (!prefix && LEGACY_KEYS.has(key)) {
			continue;
		}

		if (!Object.hasOwn(base, key)) {
			warnings.push(`Unknown key: ${path}`);

			continue;
		}

		if (value === undefined || value === null) {
			continue;
		}

		const expected = expectedType(path, base[key], value);

		if (expected) {
			warnings.push(`${path}: expected ${expected}, got ${JSON.stringify(value)}`);

			continue;
		}

		if (MODEL_LIMITS.has(path)) {
			// Model maps replace the previous layer; protected lists are additive.
			base[key] = { ...value };
		} else if (Array.isArray(base[key])) {
			base[key] = [...new Set([...base[key], ...value])];
		} else if (isObject(base[key])) {
			mergeConfig(base[key], value, warnings, path);
		} else {
			base[key] = value;
		}

		if (POSITIVE.has(path) && value < 1) {
			warnings.push(`${path}: expected positive number (>= 1)`);
		}
	}
}

function isObject(value) {
	return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isLimit(value) {
	return typeof value === "number" || typeof value === "string" && /^\d+(?:\.\d+)?%$/.test(value);
}

function expectedType(path, fallback, value) {
	if (CHOICES[path]) {
		return CHOICES[path].includes(value) ? null : CHOICES[path].join(" | ");
	}

	if (LIMITS.has(path)) {
		return isLimit(value) ? null : "number or percentage";
	}

	if (MODEL_LIMITS.has(path)) {
		return isObject(value) && Object.values(value).every(isLimit) ? null : "model-to-limit map";
	}

	if (Array.isArray(fallback)) {
		return Array.isArray(value) && value.every((entry) => typeof entry === "string") ? null : "string[]";
	}

	if (isObject(fallback)) {
		return isObject(value) ? null : "object";
	}

	return typeof value === typeof fallback ? null : typeof fallback;
}

function scheduleWarning(context, path, warnings) {
	const timer = setTimeout(async () => {
		try {
			await context?.client?.tui?.showToast({
				body: {
					title: "DCP: config warning",
					message: `${path}\n${warnings.join("\n")}`,
					variant: "warning",
					duration: 7000
				}
			});
		} catch {}
	}, 7000);

	timer.unref();
}
