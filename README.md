# env

All my configuration files and environment setup for Windows (Rio/Clink) and Linux (Bash/Arch).

## Structure

- `.vscode/`: `keybinds.json` for vscode
- `bash/`: `.bashrc` for linux
- `biome/`: biome config
- `clink/`: lua scripts and settings for clink
- `fonts/`: required/nice fonts
- `git/`: git configuration and better defaults
- `rio/`: rio configuration and catppuccin themes
- `starship/`: starship prompt config
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

## Software

A list of nice/cool tools and utilities can be found in [software.md](software.md).
