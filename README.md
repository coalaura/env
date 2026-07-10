# env

All my configuration files and environment setup for Windows (Rio/Clink) and Linux (Bash/Arch).

## Structure

- `ahk/`: autohotkey scripts
- `bash/`: `.bashrc`, `.bash_profile`, `.profile` and `.inputrc` for linux
- `biome/`: biome config
- `clink/`: lua scripts and settings for clink
- `code/`: `keybinds.json` and `settings.json` for vscode
- `discord/`: catppuccin discord theme for vencord
- `fonts/`: required/nice fonts
- `git/`: git configuration and better defaults
- `go/`: go configurations like staticcheck
- `rio/`: rio configuration and catppuccin themes
- `starship/`: starship prompt config
- `workflows/`: ci workflows commonly used
- `background.png`: clean catppuccin wallpaper

## Usage

### Sync Configs

Copies configuration files from the repo to their respective system locations (e.g., `%LOCALAPPDATA%` or `~/.config`). It also performs a first-time check for essential dependencies like starship, bun and ripgrep.

- **Windows**: Run `update.cmd`
- **Linux**: Run `./update.sh`

### Setup

Installs and upgrades installed software, using the [upgrader](.upgrader) binary.

- **Windows**: Run `setup.cmd` (auto-elevates via `sudo`)
- **Linux**: Run `sudo ./setup.sh`

### Discord

Import the theme in Quick-CSS/etc. (Vencord/Vesktop):

```css
@import url("https://coalaura.github.io/env/css/discord.min.css");
```

## Software

A list of nice/cool tools and utilities can be found in [software.md](software.md).
