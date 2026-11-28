import { resolveEffectiveCompressPermission } from "./host-permissions.js";
import { getLastUserMessage } from "./messages/query.js";

export const compressPermission = (state, config) => {
	return state.compressPermission ?? config.compress.permission;
};

export const syncCompressPermissionState = (state, config, hostPermissions, messages) => {
	const activeAgent = getLastUserMessage(messages)?.info.agent;

	state.compressPermission = resolveEffectiveCompressPermission(config.compress.permission, hostPermissions, activeAgent);
};
