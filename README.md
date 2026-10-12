# env

All my configuration files and environment setup for Windows (Rio/Clink) and Linux (Bash/Arch).

## Structure

- `ahk/`: autohotkey scripts
- `bash/`: `.bashrc`, `.bash_profile`, `.profile` and `.inputrc` for linux
- `clink/`: lua scripts and settings for clink
- `code/`: `keybinds.json` and `settings.json` for vscode
- `discord/`: catppuccin discord theme for vencord
- `equalized/`: equalizer APO config for better sound
- `fonts/`: required/nice fonts
- `git/`: git configuration and better defaults
- `rio/`: rio configuration and catppuccin themes
- `slop/`: ai related settings/configs (e.g. opencode)
- `starship/`: starship prompt config
- `workflows/`: ci workflows commonly used
- `background.png`: clean catppuccin wallpaper

## Usage

### Sync Configs

Copies configuration files from the repo to their respective system locations (e.g., `%LOCALAPPDATA%` or `~/.config`). It also performs a first-time check for essential dependencies like starship, bun and ripgrep.

- **Windows**: Run `update.cmd`
- **Linux**: Run `./update.sh`

### Setup

Installs and upgrades software using [tap](https://github.com/coalaura/tap). Setup updates an existing tap installation with `tap tap`, which checks the latest stable release. If tap is missing, setup downloads the latest release, verifies its SHA-256 checksum and installs it to `%USERPROFILE%\.bin\tap.exe` on Windows or `/usr/local/bin/tap` on Linux. It then runs `tap get` for the configured packages and syncs configuration files. Linux SSH sessions only install `go`, `time` and `wtf`.

- **Windows**: Run `setup.cmd` (auto-elevates via `sudo`)
- **Linux**: Run `./setup.sh` (uses `sudo` for system installs)

### Discord

Import the theme in Quick-CSS/etc. (Vencord/Vesktop):

```css
@import url("https://coalaura.github.io/env/css/discord.min.css");
```

## Software

A list of nice/cool tools and utilities can be found in [software.md](software.md).
