#!/bin/bash

set -euo pipefail

if [[ $EUID -eq 0 && -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
	INVOKING_USER="$SUDO_USER"
	INVOKING_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"

	run_as_user() {
		sudo -u "$INVOKING_USER" env HOME="$INVOKING_HOME" "$@"
	}
else
	run_as_user() {
		"$@"
	}
fi

run_as_root() {
	if [[ $EUID -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

echo "Pulling..."

run_as_user git pull

echo "Loading upgrader..."

UPGRADER_TMP="$(run_as_root mktemp /usr/local/bin/.env_upgrader.XXXXXX)"
UPGRADER_HASH="${UPGRADER_TMP}.sha256"

cleanup_upgrader() {
	run_as_root rm -f "$UPGRADER_TMP" "$UPGRADER_HASH"
}

trap cleanup_upgrader EXIT

run_as_root curl -fsSL --connect-timeout 15 --max-time 900 -o "$UPGRADER_TMP" "https://coalaura.github.io/env/bin/upgrader-linux"
run_as_root curl -fsSL --connect-timeout 15 --max-time 900 -o "$UPGRADER_HASH" "https://coalaura.github.io/env/bin/upgrader-linux.sha256"

EXPECTED_HASH="$(run_as_root cat "$UPGRADER_HASH")"
ACTUAL_HASH="$(run_as_root sha256sum "$UPGRADER_TMP")"
ACTUAL_HASH="${ACTUAL_HASH%% *}"

if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
	echo "Failed to verify upgrader" >&2

	exit 1
fi

echo "Running upgrader..."

run_as_root chmod +x "$UPGRADER_TMP"

# skip coreutils (only needed on windows)
TOOLS=(go time wtf)

# skip development tools, if connected via ssh
if [[ -z "${SSH_CLIENT:-}" ]]; then
	TOOLS+=(starship zig upx bun biome vet)
fi

run_as_root env "GITHUB_TOKEN=${GITHUB_TOKEN:-}" "$UPGRADER_TMP" "${TOOLS[@]}"

run_as_user bash update.sh
