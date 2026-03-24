#!/bin/bash

set -euo pipefail

echo "Loading upgrader..."

sudo curl -fsSL -o /usr/local/bin/.env_upgrader_tmp "https://coalaura.github.io/env/upgrader_linux"

if [ ! -s "/usr/local/bin/.env_upgrader_tmp" ] || [ "$(stat -c%s "/usr/local/bin/.env_upgrader_tmp")" -lt 256 ]; then
	echo "Failed to download upgrader" >&2

	rm -f "/usr/local/bin/.env_upgrader_tmp"
else
	echo "Running upgrader..."

	sudo chmod +x /usr/local/bin/.env_upgrader_tmp

	TOOLS=(go biome zig upx bun time ls)

	if [[ -z "${SSH_CLIENT:-}" ]]; then
		TOOLS+=(starship)
	fi

	sudo /usr/local/bin/.env_upgrader_tmp "${TOOLS[@]}"

	sudo rm -f /usr/local/bin/.env_upgrader_tmp
fi

bash update.sh

echo "Done."