#!/bin/bash

set -euo pipefail

# update bun
(
	if ! command -v bun >/dev/null 2>&1; then
		echo Bun is not installed, skipping...

		exit 0
	fi

	echo "Updating bun..."

	bun upgrade
)

# update biome
(
	if ! command -v biome >/dev/null 2>&1; then
		echo Biome is not installed, skipping...

		exit 0
	fi

	# get current version
	B_CURR="$(biome version | awk '/^CLI:/ {print $2}')"

	# get latest version
	echo "Checking latest biome version..."

	B_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' 'https://github.com/biomejs/biome/releases/latest')"
	B_LATEST="${B_URL##*@}"

	if [[ -z "$B_LATEST" || ! "$B_LATEST" =~ ^[0-9]+(\.[0-9]+){1,2}(-[0-9A-Za-z.-]+)?$ ]]; then
		echo "Unable to retrieve latest biome version."

		exit 0
	fi

	if [[ "$B_CURR" == "$B_LATEST" ]]; then
		echo "Biome ${B_CURR} is up to date."

		exit 0
	fi

	echo "Updating biome from ${B_CURR} to ${B_LATEST}..."

	if pgrep -x biome >/dev/null 2>&1; then
		echo "Biome is currently running, skipping download..."

		exit 0
	fi

	sudo curl -fsSL "https://github.com/biomejs/biome/releases/download/@biomejs/biome@$B_LATEST/biome-linux-x64" -o /usr/local/bin/biome
	sudo chmod +x /usr/local/bin/biome
)

echo "Done."
