#!/bin/bash

set -euo pipefail

echo "Updating configuration files..."

mkdir -p ~/.config

# bash configs
echo "Copying bash env..."

cp bash/.shenv ~/.shenv

cp bash/.bash_profile ~/.bash_profile
cp bash/.profile ~/.profile
cp bash/.bashrc ~/.bashrc
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

# firefox config
for FIREFOX_DIR in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox" "$HOME/snap/firefox/common/.mozilla/firefox" "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"; do
	[[ -f "$FIREFOX_DIR/profiles.ini" ]] || continue

	echo "Copying firefox config..."

	FIREFOX_RELATIVE=1

	while IFS='=' read -r FIREFOX_KEY FIREFOX_VALUE || [[ -n "$FIREFOX_KEY" ]]; do
		FIREFOX_VALUE="${FIREFOX_VALUE%$'\r'}"

		case "$FIREFOX_KEY" in
			IsRelative) FIREFOX_RELATIVE="$FIREFOX_VALUE" ;;
			Path)
				FIREFOX_PROFILE="$FIREFOX_VALUE"

				if [[ "$FIREFOX_RELATIVE" == "1" ]]; then
					FIREFOX_PROFILE="$FIREFOX_DIR/$FIREFOX_PROFILE"
				fi

				[[ -d "$FIREFOX_PROFILE" ]] || continue

				mkdir -p "$FIREFOX_PROFILE/chrome"

				cp -f firefox/userChrome.css "$FIREFOX_PROFILE/chrome/userChrome.css"
				cp -f firefox/user.js "$FIREFOX_PROFILE/user.js"
				;;
		esac
	done < "$FIREFOX_DIR/profiles.ini"
done

echo "Done."
