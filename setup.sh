#!/bin/bash

set -euo pipefail

echo "Loading upgrader..."

sudo curl -fsSL -o /tmp/env_upgrader_linux "https://coalaura.github.io/env/upgrader_linux"

if [ ! -s "/tmp/env_upgrader_linux" ] || [ "$(stat -c%s "/tmp/env_upgrader_linux")" -lt 256 ]; then
	echo "Failed to download upgrader" >&2

	rm -f "/tmp/env_upgrader_linux"
else
	echo "Running upgrader..."

	sudo chmod +x /tmp/env_upgrader_linux

	TOOLS=(go biome zig upx bun time ls)

	if [[ -z "${SSH_CLIENT:-}" ]]; then
		TOOLS+=(starship)
	fi

	sudo /tmp/env_upgrader_linux "${TOOLS[@]}"

	sudo rm -f /tmp/env_upgrader_linux
fi

echo "Done."