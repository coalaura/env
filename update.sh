#!/bin/bash

set -euo pipefail

# rio config
echo "Copying rio config..."

mkdir -p ~/.config/rio/themes

cp rio/config.toml ~/.config/rio/config.toml
cp rio/themes/catppuccin-macchiato.toml ~/.config/rio/themes/catppuccin-macchiato.toml

# starship config
echo "Copying starship config..."

cp starship/starship.toml ~/.config/starship.toml

# biome config
echo "Copying biome config..."

cp biome/biome.json ~/biome.json

# .bashrc
echo "Copying .bashrc..."

cp bash/.bashrc ~/.bashrc

# dependencies
echo "Checking dependencies..."

# install starship
if ! command -v starship >/dev/null 2>&1; then
	echo "Installing starship..."
	sudo pacman -Sy starship
fi

# install ripgrep
if ! command -v rg >/dev/null 2>&1; then
	echo "Installing ripgrep..."
	sudo pacman -Sy ripgrep
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
fi

echo "Done."
