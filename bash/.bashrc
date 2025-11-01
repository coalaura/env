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

		print_time "remove old package caches"
		sudo paccache -rk2 -ruk0 >/dev/null 2>&1 || true

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
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		printf "\033[37mpulling %s\033[0m\n" "$target"

		git -C "$target" pull --rebase
	)
}

# add, commit and push a given repo
function push() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		printf "\033[37mchecking %s\033[0m\n" "$target"

		if git -C "$target" diff-index --quiet HEAD -- 2>/dev/null; then
			printf "\033[33merror: nothing to commit\033[0m\n"

			return 0
		fi

		git -C "$target" status -sb

		local msg

		read -rp "message: " msg

		msg="$(echo "$msg" | xargs)"

		if [[ -z "$msg" ]]; then
			msg="update"
		fi

		printf "\033[37mpushing %s\033[0m\n" "$target"

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
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local url=$(git -C "$target" remote get-url origin 2>/dev/null)

		if [[ -z "$url" ]]; then
			printf "\033[33merror: failed to get remote\033[0m\n"

			return 1
		fi

		printf "\033[37morigin: %s\033[0m\n" "$url"
	)
}

# convert https to ssh git repo
function git_ssh() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local http=$(git -C "$target" remote get-url origin 2>/dev/null)

		if [[ -z "$http" ]]; then
			printf "\033[33merror: failed to get remote\033[0m\n"

			return 1
		fi

		if [[ ! "$http" =~ \.git$ ]]; then
			http="${http}.git"
		fi

		local ssh=$(echo "$http" | sed -E 's#^https://github\.com/([^/]+)/(.+)\.git#git@github.com:\1/\2.git#')

		if [[ "$http" == "$ssh" ]]; then
			printf "\033[33merror: already an ssh remote\033[0m\n"

			return 1
		fi

		git -C "$target" remote set-url origin "$ssh"

		printf "\033[32msuccess: set remote to %s\033[0m\n" "$ssh"
	)
}

# run a project
function run() (
	(
		set -euo pipefail

		local target="${1:-.}"

		target="$(realpath "$target")"

		# handle run script
		if [[ -f "$target/run.sh" ]]; then
			printf "\033[37m[run.sh] running %s\033[0m\n" "$target"

			cd "$target"

			chmod +x ./run.sh 2>/dev/null
			./run.sh

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			printf "\033[37m[go] running %s\033[0m\n" "$target"

			go run -C "$target" .

			return
		fi

		# handle node project
		if [[ -f "$target/package.json" ]]; then
			local script=""

			while IFS= read -r line; do
				case "$line" in
					*\"dev\"*:*)   script="${script:-dev}" ;;
					*\"watch\"*:*) script="${script:-watch}" ;;
					*\"start\"*:*) script="${script:-start}" ;;
					*\"test\"*:*) script="${script:-test}" ;;
				esac
			done < "$target/package.json"

			if [[ -z "$script" ]]; then
				printf "\033[33merror: no script found in package.json\033[0m\n" "$target"

				return
			fi

			printf "\033[37m[bun/%s] running %s\033[0m\n" "$script" "$target"

			bun run --cwd "$target" "$script"

			return
		fi

		printf "\033[33merror: %s is not a recognized project\033[0m\n" "$target"
	)
)

# build a project
function build() (
	(
		set -euo pipefail

		local target_os="linux"
		local target="."

		local -a argv=("$@")

		if ((${#argv[@]} > 0)); then
			local last="${argv[${#argv[@]}-1]}"

			local lower="${last,,}"

			case "$lower" in
				win|windows)
					target_os="windows"
					unset 'argv[${#argv[@]}-1]'
					;;
				lin|linux)
					target_os="linux"
					unset 'argv[${#argv[@]}-1]'
					;;
				dar|darwin)
					target_os="darwin"
					unset 'argv[${#argv[@]}-1]'
					;;
			esac

			printf -v target "%s" "${argv[*]}"
		fi

		target="$(realpath "$target")"

		# handle build script
		if [[ -f "$target/build.sh" ]]; then
			printf "\033[37m[build.sh] building %s\033[0m\n" "$target"

			cd "$target"

			chmod +x ./build.sh 2>/dev/null
			./build.sh

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			local base

			base="$(basename "$target")"
			base="${base//[[:space:]]/}"

			printf "\033[37m[go/%s] building %s\033[0m\n" "$base" "$target"

			if [[ "$target_os" == "windows" ]]; then
				base="$base.exe"
			fi

			GOOS="$target_os" go build -C "$target" -o "$base"

			return
		fi

		# handle node project
		if [[ -f "$target/package.json" ]]; then
			local script=""

			while IFS= read -r line; do
				case "$line" in
					*\"build\"*:*) script="${script:-build}" ;;
					*\"prod\"*:*)  script="${script:-prod}"  ;;
				esac
			done < "$target/package.json"

			if [[ -z "$script" ]]; then
				printf "\033[33merror: no script found in package.json\033[0m\n"

				return
			fi

			printf "\033[37m[bun/%s] building %s\033[0m\n" "$script" "$target"

			bun run --cwd "$target" "$script"

			return
		fi

		printf "\033[33merror: %s is not a recognized project\033[0m\n" "$target"
	)
)

__build_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    COMPREPLY=()

    if (( COMP_CWORD == 1 )); then
        compopt -o dirnames

        COMPREPLY=( $(compgen -d -- "$cur") )

        return 0
    fi

    local -a os_tokens=(win windows lin linux dar darwin)

    local t

    for t in "${os_tokens[@]}"; do
        [[ $t == "$cur"* ]] && COMPREPLY+=( "$t" )
    done
}

# update a go project
function goup() {
	(
		set -euo pipefail

		local target="${1:-.}"

		target=$(realpath "$target")

		if [ ! -f "$target/go.mod" ]; then
			printf "\033[33merror: %s is not a go project\033[0m\n" "$target"

			return 1
		fi

		local gv=$(go version | awk '{print $3}' | sed 's/^go//')

		go -C "$target" mod edit -go "$gv"

		printf "\033[32msuccess: set go version to %s\n" "$gv"

		go -C "$target" get -u ./...

		go -C "$target" mod tidy

		printf "\033[32msuccess: updated packages\033[0m\n"
	)
}

# run biome check
function bio() {
	biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path="$HOME/biome.json"
}

# download and run vencord installer
function vencord() {
	sh -c "$(curl -sS https://vencord.dev/install.sh)"
}

# trigger terminal bell
function beep() {
	printf '\a'
}

# Only show directories for certain completions
complete -d cd

complete -o dirnames -A directory pull push git_ssh origin run goup
complete -F __build_complete build

# various aliases
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -la'
alias ..='cd ..'
alias ...='cd ../..'
alias home='cd ~'

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
bind 'TAB:menu-complete'

bind 'set completion-ignore-case on'
bind 'set show-all-if-ambiguous on'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set menu-complete-display-prefix on'
bind 'set mark-symlinked-directories on'

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

# sign pushes, commits and tags
git config --global gpg.format ssh
git config --global user.signingkey "$HOME/.ssh/keys/github"
git config --global commit.gpgSign true
git config --global tag.gpgSign true

# print welcome message
printf " \\    /\\ \n"
printf "  )  ( ')  \033[0;32m%s\033[0m\n" "$(hostname | tr -d '[:space:]')"
printf " (  /  )   \033[0;35m%s\033[0m\n" "$(date +"%A, %d %b %Y, %I:%M %p")"
printf "  \\(__)|\n\n"

# init starship
eval "$(starship init bash)"