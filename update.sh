#!/bin/bash

set -euo pipefail

echo "Updating configuration files..."

mkdir -p ~/.config

# .bash_profile
echo "Copying .bash_profile..."

cp bash/.bash_profile ~/.bash_profile

# .profile
echo "Copying .profile..."

cp bash/.profile ~/.profile

# .bashrc
echo "Copying .bashrc..."

cp bash/.bashrc ~/.bashrc

# .inputrc
echo "Copying .inputrc..."

cp bash/.inputrc ~/.inputrc

# git config
if command -v git >/dev/null 2>&1; then
	echo "Copying git config..."
	cp git/.gitconfig ~/.config/.gitconfig_env
fi

# skip the rest, if connected via ssh
if [[ -n "${SSH_CLIENT:-}" ]]; then
	echo "Done."
	exit 0
fi

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

# opencode config
OPENCODE_DIR="$HOME/.config/opencode"

if [ -d "$OPENCODE_DIR" ]; then
    echo "Copying opencode config..."

    # non jsonc/json
    rm -f "$OPENCODE_DIR/opencode.json"
    rm -f "$OPENCODE_DIR/tui.json"
    rm -f "$OPENCODE_DIR/dcp.json"

    # not yet v2
    rm -f "$OPENCODE_DIR/cli.json"
    rm -f "$OPENCODE_DIR/cli.jsonc"

    # cleanly copy commands
    rsync -a --delete "slop/commands/" "$OPENCODE_DIR/commands/"

    # cleanly copy plugins
    rsync -a --delete "slop/plugins/" "$OPENCODE_DIR/plugins/"

    # cleanly copy skills
    rsync -a --delete "slop/skills/" "$OPENCODE_DIR/skills/"

    # copy configs
    cp "slop/opencode.jsonc" "$OPENCODE_DIR/opencode.jsonc"
    cp "slop/tui.jsonc" "$OPENCODE_DIR/tui.jsonc"
    cp "slop/dcp.jsonc" "$OPENCODE_DIR/dcp.jsonc"

    cp "slop/AGENTS.md" "$OPENCODE_DIR/AGENTS.md"
fi

# vscode keybinds and snippets
if [[ -d "$HOME/.config/Code/User" ]]; then
	echo "Copying vscode config..."

	cp code/keybinds.json ~/.config/Code/User/keybindings.json

	mkdir -p "$HOME/.config/Code/User/snippets"

	cp code/default.code-snippets "$HOME/.config/Code/User/snippets/default.code-snippets"
fi

echo "Done."
