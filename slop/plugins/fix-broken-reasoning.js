function rejectedItem(error) {
	const data = error?.data;

	if (!data) {
		return;
	}

	let detail;

	if (typeof data.responseBody === "string") {
		try {
			const body = JSON.parse(data.responseBody);

			detail = body?.error ?? body;
		} catch {
			detail = {
				message: data.responseBody
			};
		}
	}

	for (const message of [detail?.message, data.message]) {
		if (typeof message !== "string") {
			continue;
		}

		const item = /encrypted content for item ['"`]?(rs_[\w-]+)['"`]? could not be verified/i.exec(message);

		if (item) {
			return {
				id: item[1]
			};
		}

		const blob = /encrypted content ['"`]?([\w+=/-]+)(?:(?:\.{3}|…)([\w+=/-]+))?['"`]? could not be verified/i.exec(message);

		if (blob) {
			return {
				start: blob[1],
				end: blob[2]
			};
		}
	}
}

function matches(rejection, item) {
	if (rejection.id) {
		return item.id === rejection.id;
	}

	return item.blobs.some(blob => rejection.end
		? blob.startsWith(rejection.start) && blob.endsWith(rejection.end)
		: blob === rejection.start);
}

export const RecoverEncryptedReasoning = async () => ({
	"experimental.chat.messages.transform": async (_input, { messages }) => {
		const activeModel = messages.findLast(message => message.info.role === "user")?.info.model,
			failures = [];

		for (const [index, { info }] of messages.entries()) {
			if (info.role !== "assistant") {
				continue;
			}

			if (activeModel && (info.modelID !== activeModel.modelID || info.providerID !== activeModel.providerID)) {
				continue;
			}

			const rejection = rejectedItem(info.error)

			if (rejection) {
				failures.push({
					index: index,
					info: info,
					rejection: rejection
				});
			}
		}

		if (!failures.length) {
			return;
		}

		const items = [];

		for (const [index, { info, parts }] of messages.entries()) {
			if (info.role !== "assistant") {
				continue;
			}

			if (info.error) {
				// V1 can replay a partially completed, interrupted assistant turn.
				if (info.error.name !== "MessageAbortedError") {
					continue;
				}

				if (!parts.some(part => part.type !== "step-start" && part.type !== "reasoning")) {
					continue;
				}
			}

			// One Responses reasoning item can span several OpenCode summary parts.
			const groups = new Map()

			for (const part of parts) {
				if (part.type !== "reasoning") {
					continue;
				}

				const meta = part.metadata?.openai ?? part.metadata?.azure;

				if (!meta) {
					continue;
				}

				const key = meta.itemId || part;

				let item = groups.get(key);

				if (!item) {
					item = {
						id: meta.itemId,
						index: index,
						info: info,
						blobs: [],
						parts: []
					};

					groups.set(key, item);
				}

				item.parts.push(part);

				if (typeof meta.reasoningEncryptedContent === "string") {
					item.blobs.push(meta.reasoningEncryptedContent);
				}
			}

			for (const item of groups.values()) {
				items.push(item);
			}
		}

		const omit = new Set();

		for (const { index, info, rejection } of failures) {
			const candidates = items.filter(item => item.index < index && item.info.sessionID === info.sessionID && item.info.providerID === info.providerID && item.info.modelID === info.modelID && matches(rejection, item));

			if (candidates.length === 1) {
				for (const part of candidates[0].parts) {
					omit.add(part);
				}
			}
		}

		if (!omit.size) {
			return;
		}

		for (const message of messages) {
			if (message.parts.some(part => omit.has(part))) {
				message.parts = message.parts.filter(part => !omit.has(part));
			}
		}
	}
});
