#!/bin/bash

set -euo pipefail

# update pacman packages
(
	echo "Updating starship/ripgrep..."

	sudo pacman -Sy starship ripgrep
)

# run upgrader
(
	echo "Loading upgrader..."

	curl -fsSL -o /tmp/env_upgrader_linux "https://coalaura.github.io/env/upgrader_linux"

	if [ ! -s "/tmp/env_upgrader_linux" ] || [ "$(stat -c%s "/tmp/env_upgrader_linux")" -lt 256 ]; then
		echo "Failed to download upgrader" >&2

		rm -f "/tmp/env_upgrader_linux"

		exit 1
	fi

	echo "Running upgrader..."

	chmod +x /tmp/env_upgrader_linux

	/tmp/env_upgrader_linux

	rm -f /tmp/env_upgrader_linux
)

echo "Done."
