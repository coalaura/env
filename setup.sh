#!/bin/bash

set -euo pipefail

echo "Setting up and upgrading dependencies..."

apt_updated=false

install_or_upgrade_pkg() {
	local arch_pkg="$1"
	local deb_pkg="${2:-$1}"

	if command -v pacman >/dev/null 2>&1; then
		sudo pacman -Sy --noconfirm "$arch_pkg"
	elif command -v apt-get >/dev/null 2>&1; then
		if [[ "$apt_updated" == false ]]; then
			sudo apt-get update -qq

			apt_updated=true
		fi

		sudo apt-get install -y "$deb_pkg"
	else
		echo "Unsupported package manager. Please install/upgrade $arch_pkg manually."
	fi
}

# ripgrep
echo "Installing/Upgrading ripgrep..."

install_or_upgrade_pkg ripgrep

# upx
echo "Installing/Upgrading upx..."

install_or_upgrade_pkg upx upx-ucl

# starship
echo "Installing/Upgrading starship..."

if command -v pacman >/dev/null 2>&1; then
	sudo pacman -Sy --noconfirm starship
else
	curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# bun
echo "Installing/Upgrading bun..."

if ! command -v bun >/dev/null 2>&1; then
	curl -fsSL https://bun.com/install | bash
else
	bun upgrade
fi

# biome
echo "Installing/Upgrading biome..."

sudo curl -fsSL "https://github.com/biomejs/biome/releases/latest/download/biome-linux-x64" -o /usr/local/bin/biome
sudo chmod +x /usr/local/bin/biome

# zig
if ! command -v zig >/dev/null 2>&1; then
	echo "Installing zig..."

	if command -v pacman >/dev/null 2>&1; then
		sudo pacman -Sy --noconfirm zig
	else
		curl -fsSL "https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz" -o /tmp/zig.tar.xz

		sudo mkdir -p /usr/local/zig

		sudo tar -xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1

		sudo ln -sf /usr/local/zig/zig /usr/local/bin/zig

		rm -f /tmp/zig.tar.xz
	fi
fi

# time
if ! type -P time >/dev/null 2>&1; then
	echo "Installing time..."
	curl -sL https://src.ws2.sh/time/install.sh | sh
fi

# environment upgrader
echo "Loading env upgrader..."

sudo curl -fsSL -o /tmp/env_upgrader_linux "https://coalaura.github.io/env/upgrader_linux"

if [ ! -s "/tmp/env_upgrader_linux" ] || [ "$(stat -c%s "/tmp/env_upgrader_linux")" -lt 256 ]; then
	echo "Failed to download upgrader" >&2
	rm -f "/tmp/env_upgrader_linux"
else
	echo "Running env upgrader..."

	sudo chmod +x /tmp/env_upgrader_linux

	sudo /tmp/env_upgrader_linux

	sudo rm -f /tmp/env_upgrader_linux
fi

echo "Done."