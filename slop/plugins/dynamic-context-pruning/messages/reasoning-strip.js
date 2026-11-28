import { getLastUserMessage } from "./query.js";

export function stripStaleMetadata(messages) {
	const lastUserMessage = getLastUserMessage(messages);

	if (lastUserMessage?.info.role !== "user") {
		return;
	}

	const modelID = lastUserMessage.info.model.modelID,
		providerID = lastUserMessage.info.model.providerID;

	messages.forEach((message) => {
		if (message.info.role !== "assistant") {
			return;
		}

		if (message.info.modelID === modelID && message.info.providerID === providerID) {
			return;
		}

		message.parts = message.parts.map((part) => {
			if (part.type !== "text" && part.type !== "tool" && part.type !== "reasoning") {
				return part;
			}

			if (!("metadata" in part)) {
				return part;
			}

			const { metadata: _metadata, ...rest } = part;

			return rest;
		});
	});
}
