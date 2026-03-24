#!/bin/bash

set -euo pipefail

echo "Loading upgrader..."

sudo curl -fsSL -o /tmp/env_upgrader_linux "https://coalaura.github.io/env/upgrader_linux"

if [ ! -s "/tmp/env_upgrader_linux" ] || [ "$(stat -c%s "/tmp/env_upgrader_linux")" -lt 256 ]; then
	echo "Failed to download upgrader" >&2
	rm -f "/tmp/env_upgrader_linux"
else
	echo "Running env upgrader..."

	sudo chmod +x /tmp/env_upgrader_linux

	sudo /tmp/env_upgrader_linux go biome zig upx starship bun time ls

	sudo rm -f /tmp/env_upgrader_linux
fi

echo "Done."