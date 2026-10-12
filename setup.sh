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

TAP_BIN="/usr/local/bin/tap"

if [[ ! -x "$TAP_BIN" ]]; then
	TAP_BIN="$(type -P tap || true)"
fi

if [[ -n "$TAP_BIN" ]]; then
	echo "Checking for tap updates..."

	run_as_root env "GITHUB_TOKEN=${GITHUB_TOKEN:-}" "$TAP_BIN" tap
else
	if [[ "$(uname -m)" != "x86_64" ]]; then
		echo "Tap releases currently require Linux amd64" >&2

		exit 1
	fi

	echo "Checking the latest tap release..."

	TAP_RELEASE="$(curl -fsSL --connect-timeout 15 --max-time 60 -o /dev/null -w '%{url_effective}' "https://github.com/coalaura/tap/releases/latest")"
	TAP_VERSION="${TAP_RELEASE##*/}"

	if [[ "$TAP_RELEASE" != "https://github.com/coalaura/tap/releases/tag/"* ]]; then
		echo "Failed to resolve the latest tap release" >&2

		exit 1
	fi

	TAP_RELEASE="https://github.com/coalaura/tap/releases/download/$TAP_VERSION"
	TAP_BIN="/usr/local/bin/tap"

	run_as_root mkdir -p /usr/local/bin
	TAP_TMP="$(run_as_root mktemp -d /usr/local/bin/.tap.XXXXXX)"

	cleanup_tap() {
		run_as_root rm -rf -- "$TAP_TMP"
	}

	trap cleanup_tap EXIT

	echo "Installing tap $TAP_VERSION..."

	run_as_root curl -fsSL --connect-timeout 15 --max-time 900 -o "$TAP_TMP/tap" "$TAP_RELEASE/tap-linux-amd64"
	run_as_root curl -fsSL --connect-timeout 15 --max-time 900 -o "$TAP_TMP/SHA256SUMS" "$TAP_RELEASE/SHA256SUMS"

	EXPECTED_HASH="$(run_as_root awk '$2 == "*tap-linux-amd64" || $2 == "tap-linux-amd64" { print $1 }' "$TAP_TMP/SHA256SUMS")"
	ACTUAL_HASH="$(run_as_root sha256sum "$TAP_TMP/tap")"
	ACTUAL_HASH="${ACTUAL_HASH%% *}"

	if [[ ! "$EXPECTED_HASH" =~ ^[[:xdigit:]]{64}$ || "$ACTUAL_HASH" != "${EXPECTED_HASH,,}" ]]; then
		echo "Failed to verify tap" >&2

		exit 1
	fi

	run_as_root chmod 755 "$TAP_TMP/tap"
	run_as_root mv -f "$TAP_TMP/tap" "$TAP_BIN"

	cleanup_tap
	trap - EXIT
fi

export PATH="/usr/local/bin:$PATH"

# skip coreutils (only needed on windows)
TOOLS=(go time wtf)

# skip development tools, if connected via ssh
if [[ -z "${SSH_CLIENT:-}" ]]; then
	TOOLS+=(starship zig upx bun builder vet actup license mksvc)
fi

run_as_root env "GITHUB_TOKEN=${GITHUB_TOKEN:-}" "$TAP_BIN" get "${TOOLS[@]}"

run_as_user bash update.sh
