#!/bin/bash

set -euo pipefail

echo "Updating configuration files..."

# rio config
if command -v rio >/dev/null 2>&1; then
	echo "Copying rio config..."

	mkdir -p ~/.config/rio/themes

	cp rio/config.toml ~/.config/rio/config.toml
	cp rio/themes/catppuccin-macchiato.toml ~/.config/rio/themes/catppuccin-macchiato.toml
fi

# starship config
if command -v starship >/dev/null 2>&1; then
	echo "Copying starship config..."
	cp starship/starship.toml ~/.config/starship.toml
fi

# git config
if command -v git >/dev/null 2>&1; then
	echo "Copying git config..."
	cp git/.gitconfig ~/.config/.gitconfig_env
fi

# biome config
if command -v biome >/dev/null 2>&1; then
	echo "Copying biome config..."
	cp biome/biome.json ~/biome.json
fi

# .bashrc
echo "Copying .bashrc..."

cp bash/.bashrc ~/.bashrc

# vscode keybinds.json
if [[ -d "$HOME/.config/Code/User" ]]; then
	echo "Copying vscode keybinds..."
	cp .vscode/keybinds.json ~/.config/Code/User/keybindings.json
fi

echo "Done."
