#!/bin/bash

set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script must be run as root (sudo)."
	echo "Try: sudo $0 $*"

	exit 1
fi

# update packages
(
	echo "Updating starship/ripgrep..."

	if command -v pacman >/dev/null 2>&1; then
		pacman -Sy --noconfirm starship ripgrep
	elif command -v apt-get >/dev/null 2>&1; then
		apt-get update -qq
		apt-get install -y ripgrep

		# Update starship via official script on Debian
		curl -sS https://starship.rs/install.sh | sh -s -- -y
	else
		echo "Unsupported package manager. Please update starship and ripgrep manually."
	fi
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
