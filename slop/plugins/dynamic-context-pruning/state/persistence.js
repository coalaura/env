import * as fs from "fs/promises";
import { existsSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import { serializePruneMessagesState } from "./utils.js";

const STORAGE_DIR = join(process.env.XDG_DATA_HOME || join(homedir(), ".local", "share"), "opencode", "storage", "plugin", "dcp"),
	pendingWrites = new Map();

async function ensureStorageDir() {
	if (!existsSync(STORAGE_DIR)) {
		await fs.mkdir(STORAGE_DIR, { recursive: true });
	}
}

function getSessionFilePath(sessionId) {
	return join(STORAGE_DIR, `${sessionId}.json`);
}

async function writeSnapshot(sessionId, content, logger) {
	await ensureStorageDir();

	const filePath = getSessionFilePath(sessionId),
		temporaryPath = `${filePath}.${process.pid}.tmp`;

	try {
		await fs.writeFile(temporaryPath, content, "utf-8");
		await fs.rename(temporaryPath, filePath);
	} finally {
		await fs.unlink(temporaryPath).catch(() => {});
	}

	logger.info("Saved session state to disk", { sessionId: sessionId });
}

function serializeWrite(sessionId, operation) {
	const previous = pendingWrites.get(sessionId) ?? Promise.resolve(),
		pending = previous.catch(() => {}).then(operation);

	pendingWrites.set(sessionId, pending);

	void pending.finally(() => {
		if (pendingWrites.get(sessionId) === pending) {
			pendingWrites.delete(sessionId);
		}
	}).catch(() => {});

	return pending;
}

export async function saveSessionState(sessionState, logger, sessionName) {
	try {
		if (!sessionState.sessionId) {
			return;
		}

		const state = {
			sessionName: sessionName,
			manualMode: !!sessionState.manualMode,
			prune: {
				tools: Object.fromEntries(sessionState.prune.tools),
				messages: serializePruneMessagesState(sessionState.prune.messages)
			},
			nudges: {
				contextLimitAnchors: Array.from(sessionState.nudges.contextLimitAnchors),
				turnNudgeAnchors: Array.from(sessionState.nudges.turnNudgeAnchors),
				iterationNudgeAnchors: Array.from(sessionState.nudges.iterationNudgeAnchors)
			},
			stats: sessionState.stats,
			lastUpdated: new Date().toISOString()
		};

		// Snapshot before yielding: timing events can update this state during a save.
		const sessionId = sessionState.sessionId,
			content = JSON.stringify(state, null, 2);

		await serializeWrite(sessionId, () => writeSnapshot(sessionId, content, logger));
	} catch (error) {
		logger.error("Failed to save session state", {
			sessionId: sessionState.sessionId,
			error: error?.message
		});
	}
}

export async function loadSessionState(sessionId, logger) {
	await pendingWrites.get(sessionId)?.catch(() => {});

	return readSessionState(sessionId, logger);
}

async function readSessionState(sessionId, logger) {
	try {
		const filePath = getSessionFilePath(sessionId);

		if (!existsSync(filePath)) {
			return null;
		}

		const content = await fs.readFile(filePath, "utf-8"),
			state = JSON.parse(content),
			hasPruneTools = state?.prune?.tools && typeof state.prune.tools === "object",
			hasPruneMessages = state?.prune?.messages && typeof state.prune.messages === "object",
			hasNudgeFormat = state?.nudges && typeof state.nudges === "object";

		if (!state || !state.prune || !hasPruneTools || !hasPruneMessages || !state.stats || !hasNudgeFormat) {
			logger.warn("Invalid session state file, ignoring", {
				sessionId: sessionId
			});

			return null;
		}

		for (const key of ["contextLimitAnchors", "turnNudgeAnchors", "iterationNudgeAnchors"]) {
			const entries = Array.isArray(state.nudges[key]) ? state.nudges[key] : [],
				valid = entries.filter((entry) => typeof entry === "string");

			if (valid.length !== entries.length) {
				logger.warn(`Filtered out malformed ${key} entries`, { sessionId: sessionId });
			}

			state.nudges[key] = [...new Set(valid)];
		}

		logger.info("Loaded session state from disk", {
			sessionId: sessionId
		});

		return state;
	} catch (error) {
		logger.warn("Failed to load session state", {
			sessionId: sessionId,
			error: error?.message
		});

		return null;
	}
}

function emptyPersistedState(manualMode) {
	return {
		manualMode: manualMode,
		prune: {
			tools: {},
			messages: {
				byMessageId: {},
				blocksById: {},
				activeBlockIds: [],
				activeByAnchorMessageId: {},
				nextBlockId: 1,
				nextRunId: 1
			}
		},
		nudges: {
			contextLimitAnchors: [],
			turnNudgeAnchors: [],
			iterationNudgeAnchors: []
		},
		stats: {
			pruneTokenCounter: 0,
			totalPruneTokens: 0
		},
		lastUpdated: new Date().toISOString()
	};
}

export async function loadManualModeSetting(sessionId, logger) {
	const state = await loadSessionState(sessionId, logger);

	return typeof state?.manualMode === "boolean" ? state.manualMode : undefined;
}

export async function saveManualModeSetting(sessionId, manualMode, logger) {
	await serializeWrite(sessionId, async () => {
		const existing = await readSessionState(sessionId, logger),
			state = existing ?? emptyPersistedState(manualMode);

		state.manualMode = manualMode;
		state.lastUpdated = new Date().toISOString();

		await writeSnapshot(sessionId, JSON.stringify(state, null, 2), logger);
	});
}

export async function loadAllSessionStats(logger) {
	const result = {
		totalTokens: 0,
		totalTools: 0,
		totalMessages: 0,
		sessionCount: 0
	};

	try {
		if (!existsSync(STORAGE_DIR)) {
			return result;
		}

		const files = await fs.readdir(STORAGE_DIR),
			jsonFiles = files.filter((f) => f.endsWith(".json"));

		for (const file of jsonFiles) {
			try {
				const filePath = join(STORAGE_DIR, file),
					content = await fs.readFile(filePath, "utf-8"),
					state = JSON.parse(content);

				if (state?.stats?.totalPruneTokens && state?.prune) {
					result.totalTokens += state.stats.totalPruneTokens;
					result.totalTools += state.prune.tools ? Object.keys(state.prune.tools).length : 0;
					result.totalMessages += state.prune.messages?.byMessageId ? Object.keys(state.prune.messages.byMessageId).length : 0;
					result.sessionCount++;
				}
			} catch {}
		}

		logger.debug("Loaded all-time stats", result);
	} catch (error) {
		logger.warn("Failed to load all-time stats", { error: error?.message });
	}

	return result;
}
