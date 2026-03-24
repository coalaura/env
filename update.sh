#!/bin/bash

set -euo pipefail

# rio config
if command -v rio >/dev/null 2>&1; then
	echo "Copying rio config..."

	mkdir -p ~/.config/rio/themes

	cp rio/config.toml ~/.config/rio/config.toml
	cp rio/themes/catppuccin-macchiato.toml ~/.config/rio/themes/catppuccin-macchiato.toml
fi

# starship config
echo "Copying starship config..."

cp starship/starship.toml ~/.config/starship.toml

# git config
echo "Copying git config..."

cp git/.gitconfig ~/.config/.gitconfig_env

# biome config
echo "Copying biome config..."

cp biome/biome.json ~/biome.json

# .bashrc
echo "Copying .bashrc..."

cp bash/.bashrc ~/.bashrc

# vscode keybinds.json
if [[ -d "$HOME/.config/Code/User" ]]; then
	echo "Copying vscode keybinds..."

	cp .vscode/keybinds.json ~/.config/Code/User/keybindings.json
fi

# dependencies
echo "Checking dependencies..."

apt_updated=false

install_pkg() {
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
		echo "Unsupported package manager. Please install $arch_pkg manually."
	fi
}

# install starship
if ! command -v starship >/dev/null 2>&1; then
	echo "Installing starship..."
	if command -v pacman >/dev/null 2>&1; then
		sudo pacman -Sy --noconfirm starship
	else
		curl -sS https://starship.rs/install.sh | sh -s -- -y
	fi
fi

# install ripgrep
if ! command -v rg >/dev/null 2>&1; then
	echo "Installing ripgrep..."
	install_pkg ripgrep
fi

# install bun
if ! command -v bun >/dev/null 2>&1; then
	echo "Installing bun..."
	curl -fsSL https://bun.com/install | bash
fi

# install biome
if ! command -v biome >/dev/null 2>&1; then
	echo "Installing biome..."
	sudo curl -fsSL "https://github.com/biomejs/biome/releases/latest/download/biome-linux-x64" -o /usr/local/bin/biome
	sudo chmod +x /usr/local/bin/biome
fi

# install zig
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

# install upx
if ! command -v upx >/dev/null 2>&1; then
	echo "Installing upx..."
	install_pkg upx upx-ucl
fi

# install time
if ! type -P time >/dev/null 2>&1; then
	echo "Installing time..."
	curl -sL https://src.ws2.sh/time/install.sh | sh
fi

echo "Done."
