export class Sessions {
	entries = new Map();

	constructor(createRuntime) {
		this.createRuntime = createRuntime;
	}

	get(sessionId) {
		if (typeof sessionId !== "string" || !sessionId) {
			throw new Error("DCP requires a session ID");
		}

		let entry = this.entries.get(sessionId);

		if (!entry) {
			entry = {
				runtime: this.createRuntime(sessionId),
				pending: Promise.resolve()
			};

			this.entries.set(sessionId, entry);
		}

		return entry;
	}

	run(sessionId, operation) {
		const entry = this.get(sessionId),
			result = entry.pending.then(() => operation(entry.runtime));

		// A failed operation must not block later work in this session.
		entry.pending = result.catch(() => {});

		return result;
	}

	async delete(sessionId) {
		const entry = this.entries.get(sessionId);

		if (!entry) {
			return;
		}

		while (this.entries.get(sessionId) === entry) {
			const pending = entry.pending;

			await pending;

			if (entry.pending === pending) {
				this.entries.delete(sessionId);
			}
		}
	}
}

export function messageSessionId(input, messages) {
	let sessionId = input.sessionID;

	for (const message of messages ?? []) {
		const messageSession = message?.info?.sessionID;

		if (!messageSession) {
			continue;
		}

		if (sessionId && sessionId !== messageSession) {
			throw new Error("DCP received messages from multiple sessions");
		}

		sessionId = messageSession;
	}

	return sessionId;
}
