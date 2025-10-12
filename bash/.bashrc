#!/bin/bash
# ~/.bashrc
# by coalaura

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# git root detector
function git_root() {
	local path="${1:-.}"

	git -C "$path" rev-parse --show-toplevel 2>/dev/null || echo "$path"
}

# perform maintenance and updates
function update() {
	(
		set -euo pipefail

		function print_time() {
			echo "[$(date '+%H:%M:%S')] - $1"
		}

		print_time "pacman -Syu"
		sudo pacman -Syu --noconfirm > /dev/null

		print_time "paru -Syu"
		paru -Syu --noconfirm > /dev/null

		print_time "pacman -Sc"
		sudo pacman -Sc --noconfirm > /dev/null

		print_time "pacman -Rns (orphans)"
		readarray -t orphans < <(pacman -Qtdq 2>/dev/null)
		if (( ${#orphans[@]} )); then
			sudo pacman -Rns --noconfirm "${orphans[@]}" > /dev/null
		fi

		print_time "clean old logs"
		sudo find /var/log -type f -name "*.log" -mtime +14 -delete > /dev/null 2>&1 || true

		print_time "clean old /tmp"
		sudo find /tmp -type f -atime +7 -delete > /dev/null 2>&1 || true

		print_time "clean old /var/tmp"
		sudo find /var/tmp -type f -atime +7 -delete > /dev/null 2>&1 || true

		print_time "completed"
	)
}

# pull a given repo
function pull() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			echo "$target is not a git repository"

			return 1
		fi

		git -C "$target" pull --rebase
	)
}

# add, commit and push a given repo
function push() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\n" "$target"

			return 1
		fi

		if git -C "$target" diff-index --quiet HEAD --; then
			printf "\033[33merror: nothing to commit\n"

			return 0
		fi

		git -C "$target" status -sb

		local msg

		read -rp "message: " msg

		msg="$(echo "$msg" | xargs)"

		if [[ -z "$msg" ]]; then
			msg="update"
		fi

		git -C "$target" add -A
		git -C "$target" commit -m "$msg"
		git -C "$target" push
	)
}

# print git remote origin
function origin() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\n" "$target"

			return 1
		fi

		local url=$(git -C "$target" remote get-url origin)

		printf "\033[32morigin: %s\n" "$url"
	)
}

# convert https to ssh git repo
function git_ssh() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\n" "$target"

			return 1
		fi

		local http=$(git -C "$target" remote get-url origin)
		local ssh=$(echo "$http" | sed -E 's#https://github.com/([^/]+)/([^\.]+)(\.git)?#git@github.com:\1/\2.git#')

		if [[ "$http" == "$ssh" ]]; then
			printf "\033[33merror: already an ssh remote\n"

			return 1
		fi

		git -C "$target" remote set-url origin "$ssh"

		printf "\033[32msuccess: set remote to %s\n" "$ssh"
	)
}

# go run a project
function run() {
	(
		set -euo pipefail

		local target="${1:-.}"

		if [ ! -f "$target/go.mod" ]; then
			printf "\033[33merror: %s is not a go project\n" "$target"

			return 1
		fi

		cd "$target"

		go run .
	)
}

# update a go project
function goup() {
	(
		set -euo pipefail

		local target="${1:-.}"

		if [ ! -f "$target/go.mod" ]; then
			printf "\033[33merror: %s is not a go project\n" "$target"

			return 1
		fi

		cd "$target"

		local gv=$(go version | awk '{print $3}' | sed 's/^go//')

		go mod edit -go "$gv"

		printf "\033[32msuccess: set go version to %s\n" "$gv"

		go get -u ./...

		go mod tidy

		printf "\033[32msuccess: updated packages\n"
	)
}

# Only show directories for cd completion
complete -d cd

# various aliases
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -la'
alias ..='cd ..'

# Auto-correct cd typos
shopt -s cdspell
# Auto-correct completion typos
shopt -s dirspell
# Update window size
shopt -s checkwinsize
# Enable ** globbing
shopt -s globstar
# Extended pattern matching
shopt -s extglob
# Append to history
shopt -s histappend
# Multi-line commands in one history entry
shopt -s cmdhist

# Better completion
bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'

# History search with arrow keys
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Better history
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ssh-add *:password *:secret *"
export HISTSIZE=50000
export HISTFILESIZE=100000

# path additions
export PATH="$PATH:$HOME/.bun/bin"

# ensure ssh-agent is running
if [ -f "$HOME/.ssh/agent" ]; then
	source "$HOME/.ssh/agent"
fi

if ! ssh-add -l >/dev/null 2>&1; then
	umask 077

	ssh-agent -s | sed 's/^echo.*$//' > "$HOME/.ssh/agent"

	source "$HOME/.ssh/agent"
fi

# ensure github ssh key is loaded
if [ -f "$HOME/.ssh/keys/github" ]; then
	ssh-add "$HOME/.ssh/keys/github" > /dev/null 2>&1
fi

# print welcome message
printf " \\    /\\ \n"
printf "  )  ( ')  \033[0;32m%s\033[0m\n" "$(hostname | tr -d '[:space:]')"
printf " (  /  )   \033[0;35m%s\033[0m\n" "$(date +"%A, %d %b %Y, %I:%M %p")"
printf "  \\(__)|\n\n"

# init starship
eval "$(starship init bash)"