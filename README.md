# env

All my configuration files and environment setup for Windows (Rio/Clink) and Linux (Bash/Arch).

## Structure

- `bash/`: `.bashrc` for linux
- `biome/`: biome config
- `clink/`: lua scripts and settings for clink
- `git/`: git configuration and better defaults
- `rio/`: rio configuration and catppuccin themes
- `starship/`: starship prompt config
- `fonts/`: required/nice fonts
- `background.png`: clean catppuccin wallpaper

## Usage

### Sync Configs

Copies configuration files from the repo to their respective system locations (e.g., `%LOCALAPPDATA%` or `~/.config`). It also performs a first-time check for essential dependencies like starship, bun and ripgrep.

- **Windows**: Run `update.cmd`
- **Linux**: Run `./update.sh`

### Upgrade

Updates installed software (via `winget` or `pacman`), upgrades the Bun runtime and executes the [upgrader](.upgrader) binary for tool maintenance.

- **Windows**: Run `upgrade.cmd` (auto-elevates via `sudo`)
- **Linux**: Run `sudo ./upgrade.sh`

## Software

A list of nice/cool tools and utilities can be found in [software.md](software.md).
