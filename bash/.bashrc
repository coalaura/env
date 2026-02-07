#!/bin/bash
# ~/.bashrc
# by coalaura

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

##
# Helper Functions
##

# Find the directory containing package main with func main, prioritizing highest level
function _find_go_main_dir() {
    local root_dir="${1:-.}"

    root_dir=$(realpath "$root_dir")

    local has_main_pkg=false
    local has_main_func=false

    for f in "$root_dir"/*.go; do
        [[ -f "$f" ]] || continue

        if grep -q "^package main" "$f" 2>/dev/null; then
            has_main_pkg=true

            if grep -q "func main(" "$f" 2>/dev/null; then
                has_main_func=true

                break
            fi
        fi
    done

    if [[ "$has_main_pkg" == true && "$has_main_func" == true ]]; then
        echo "$root_dir"

        return
    fi

    # Find all main packages using go list
    local candidates=()

    while IFS='|' read -r pkg_name pkg_dir; do
        [[ "$pkg_name" == "main" ]] || continue
        [[ -d "$pkg_dir" ]] || continue

        for f in "$pkg_dir"/*.go; do
            [[ -f "$f" ]] || continue

            if grep -q "func main(" "$f" 2>/dev/null; then
                candidates+=("$pkg_dir")

			    break
            fi
        done
    done < <(cd "$root_dir" && go list -f '{{.Name}}|{{.Dir}}' ./... 2>/dev/null)

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "$root_dir"

        return
    fi

    # Find shallowest path (fewest slashes = highest level)
    local main_dir="${candidates[0]}"
    local min_depth=$(echo "$main_dir" | tr -cd '/' | wc -c)

    for dir in "${candidates[@]:1}"; do
        local depth=$(echo "$dir" | tr -cd '/' | wc -c)

		if [[ $depth -lt $min_depth ]]; then
            min_depth=$depth
            main_dir="$dir"
        elif [[ $depth -eq $min_depth && "$dir" < "$main_dir" ]]; then
            main_dir="$dir"
        fi
    done

    echo "$main_dir"
}

##
# Commands
##

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

		git -C "$target" add *

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

		git -C "$target" commit -m "$msg"
		git -C "$target" push
	)
}

# create and push a git tag
function tag() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local last_tag

		last_tag=$(git -C "$target" describe --tags --abbrev=0 2>/dev/null || true)

		if [[ -z "$last_tag" ]]; then
			last_tag="n/a"
		fi

		printf "\x1b[90mcurrent: %s\033[0m\n\n" "$last_tag"

		local tag_name
		local msg

		read -rp "new tag: " tag_name

		tag_name="$(echo "$tag_name" | xargs)"

		if [[ -z "$tag_name" ]]; then
			printf "\033[33merror: tag name is required\033[0m\n"

			return 1
		fi

		read -rp "message: " msg

		msg="$(echo "$msg" | xargs)"

		if [[ -z "$msg" ]]; then
			printf "\033[33merror: message is required\033[0m\n"

			return 1
		fi

		printf "\033[37mtagging %s as %s\033[0m\n" "$target" "$tag_name"

		if ! git -C "$target" tag -a "$tag_name" -m "$msg"; then
			printf "\033[33merror: failed to create tag\033[0m\n"

			return 1
		fi

		printf "\033[37mpushing tag %s\033[0m\n" "$tag_name"

		if ! git -C "$target" push origin "$tag_name"; then
			printf "\033[33merror: failed to push tag\033[0m\n"

			return 1
		fi

		printf "\033[32msuccess: tagged and pushed %s\033[0m\n" "$tag_name"
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

# discard all changes in a git repo
function trash() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local confirm

		# Explicitly prompt about the target so you don't trash the wrong repo
		read -rp "trash everything in $(basename "$target")? [y/N] " confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			printf "\033[33maborted\033[0m\n"

			return 1
		fi

		printf "\033[37mresetting...\033[0m\n"

		git -C "$target" reset --hard

		printf "\033[37mcleaning...\033[0m\n"

		git -C "$target" clean -fd

		printf "\033[32msuccess: cleaned\033[0m\n"
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

# test a project
function test() (
	(
		set -euo pipefail

		local target="$(realpath ".")"
		local -a extra_args=("$@")

		# handle test script
		if [[ -f "$target/test.sh" ]]; then
			printf "\033[37m[test.sh] testing %s\033[0m\n" "$target"

			chmod +x ./test.sh 2>/dev/null

			./test.sh "${extra_args[@]}"

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			printf "\033[37m[go] testing %s\033[0m\n" "$target"

			# enable CGO with zig
			export CGO_ENABLED=1
			export CC="zig cc"
			export CXX="zig c++"

			go test -v . "${extra_args[@]}"

			return
		fi

		# handle node project
		if [[ -f "$target/package.json" ]]; then
			local script=""

			while IFS= read -r line; do
				case "$line" in
					*\"test\"*:*)
						script="test"
						;;
				esac
			done < "$target/package.json"

			if [[ -n "$script" ]]; then
				printf "\033[37m[bun/%s] testing %s\033[0m\n" "$script" "$target"

				bun run "$script" "${extra_args[@]}"

				return
			fi

			# fallback to bun test if test files exist
			if compgen -G "$target/*.{test,spec}.{js,ts,jsx,tsx}" >/dev/null 2>&1; then
				printf "\033[37m[bun test] testing %s\033[0m\n" "$target"

				bun test "${extra_args[@]}"

				return
			fi
		fi

		printf "\033[33merror: %s is not a recognized test project\033[0m\n" "$target"
	)
)

# run a project
function run() (
	(
		set -euo pipefail

		local target="$(realpath ".")"
		local -a extra_args=("$@")

		# handle run script
		if [[ -f "$target/run.sh" ]]; then
			printf "\033[37m[run.sh] running %s\033[0m\n" "$target"

			chmod +x ./run.sh 2>/dev/null

			./run.sh "${extra_args[@]}"

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			local main_dir

			main_dir=$(_find_go_main_dir "$target")

			printf "\033[37m[go] running %s\033[0m\n" "$main_dir"

			# enable CGO with zig
			export CGO_ENABLED=1
			export CC="zig cc"
			export CXX="zig c++"

			go run "$main_dir" "${extra_args[@]}"

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

			if [[ -n "$script" ]]; then
				printf "\033[37m[bun/%s] running %s\033[0m\n" "$script" "$target"

				bun run "$script" "${extra_args[@]}"

				return
			fi
		fi

		# handle single node files
		for file in "index.js" "main.js" "app.js"; do
			if [[ -f "$target/$file" ]]; then
				printf "\033[37m[bun/%s] running %s\033[0m\n" "$file" "$target"

				bun "$file" "${extra_args[@]}"

				return
			fi
		done

		printf "\033[33merror: %s is not a recognized project\033[0m\n" "$target"
	)
)

# build a project
function build() (
	(
		set -euo pipefail

		local target_os="linux"
		local target_arch="amd64"

		local target="$(realpath ".")"
		local -a extra_args=("$@")

		# Check if first arg is a target OS
		if ((${#extra_args[@]} > 0)); then
			local first="${extra_args[0]}"
			local lower="${first,,}"

			case "$lower" in
				win|windows)
					target_os="windows"
					extra_args=("${extra_args[@]:1}")
					;;
				lin|linux)
					target_os="linux"
					extra_args=("${extra_args[@]:1}")
					;;
				dar|darwin)
					target_os="darwin"
					extra_args=("${extra_args[@]:1}")
					;;
			esac
		fi

		# Detect host arch for native builds
		local host_arch=$(uname -m)

		target_arch="$host_arch"

		case "$host_arch" in
			x86_64) host_arch="amd64" ;;
			aarch64) host_arch="arm64" ;;
		esac

		# handle build script
		if [[ -f "$target/build.sh" ]]; then
			printf "\033[37m[build.sh] building %s\033[0m\n" "$target"

			chmod +x ./build.sh 2>/dev/null

			./build.sh "${extra_args[@]}"

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			local main_dir

			main_dir=$(_find_go_main_dir "$target")

			local base

			base="$(basename "$target")"
			base="${base//[[:space:]]/}"

			printf "\033[37m[go/%s/%s] building %s\033[0m\n" "$target_os" "$base" "$main_dir"

			if [[ "$target_os" == "windows" ]]; then
				base="$base.exe"
			fi

			# Zig target mapping
			local zig_target=""

			case "$target_os/$target_arch" in
				linux/amd64)
					zig_target="x86_64-linux-musl"
					;;
				linux/arm64)
					zig_target="aarch64-linux-musl"
					;;
				windows/amd64)
					zig_target="x86_64-windows-gnu"
					;;
				windows/arm64)
					zig_target="aarch64-windows-gnu"
					;;
				darwin/amd64)
					zig_target="x86_64-macos-none"
					;;
				darwin/arm64)
					zig_target="aarch64-macos-none"
					;;
				*)
					zig_target=""
					;;
			esac

			# Static linking flags
			local ldflags="-s -w -trimpath -buildvcs=false"

			if [[ "$target_os" == "linux" ]]; then
				ldflags="$ldflags -linkmode external -extldflags '-static'"
			elif [[ "$target_os" == "windows" ]]; then
				ldflags="$ldflags -linkmode external -extldflags '-static'"
			fi

			# Cross-compilation check: use Zig when target != host
			local is_cross=false

			if [[ "$target_os" != "linux" ]]; then
				is_cross=true
			elif [[ "$target_arch" != "$host_arch" ]]; then
				is_cross=true
			fi

			# Set build environment
			export GOOS="$target_os"
			export GOARCH="$target_arch"
			export CGO_ENABLED=1

			if [[ "$is_cross" == "true" && -n "$zig_target" ]]; then
				export CC="zig cc -target $zig_target"
				export CXX="zig c++ -target $zig_target"
			else
				export CC="zig cc"
				export CXX="zig c++"
			fi

			go build -ldflags "$ldflags" -o "$base" "${extra_args[@]}" "$main_dir"

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

			bun run "$script" "${extra_args[@]}"

			return
		fi

		printf "\033[33merror: %s is not a recognized project\033[0m\n" "$target"
	)
)

__build_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"

    COMPREPLY=()

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
	biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path="$HOME/biome.json" $@
}

# download and run vencord installer
function vencord() {
	sh -c "$(curl -sS https://vencord.dev/install.sh)"
}

# trigger terminal bell
function beep() {
	printf '\a'
}

##
# Shell settings
##

# Only show directories for certain completions
complete -d cd

complete -o dirnames -A directory pull push git_ssh origin trash goup
complete -F __build_complete build

# various aliases
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -la'
alias tidy='go mod tidy'
alias ..='cd ..'
alias ...='cd ../..'
alias home='cd ~'
alias cls='clear'

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
export PATH="$PATH:/usr/local/go/bin"

# so ssh/etc properly detect the terminal
export TERM=xterm-256color

##
# CGo settings
##

export CGO_ENABLED=1
export CC="zig cc"
export CXX="zig c++"

##
# SSH Agent
##

# ensure ssh-agent is running
SSH_AGENT_FILE="$HOME/.ssh/.agent-env"

if [ -f "$SSH_AGENT_FILE" ]; then
	source "$SSH_AGENT_FILE" > /dev/null 2>&1
fi

if ! ssh-add -l >/dev/null 2>&1; then
	eval "$(ssh-agent -s)" > "$SSH_AGENT_FILE"
fi

# ensure github ssh key is loaded
if [ -f "$HOME/.ssh/keys/github" ]; then
	ssh-add "$HOME/.ssh/keys/github" > /dev/null 2>&1
fi

# ensure github ssh key is loaded
if [ -f "$HOME/.ssh/keys/github" ]; then
	ssh-add "$HOME/.ssh/keys/github" > /dev/null 2>&1
fi

##
# Git settings
##

git config --global --replace-all include.path "~/.config/.gitconfig_env" "^~/.config/.gitconfig_env$"

##
# Startup
##

# print welcome message
printf "\n \\    /\\ \n"
printf "  )  ( ')  \033[0;32m%s\033[0m\n" "$(hostname | tr -d '[:space:]')"
printf " (  /  )   \033[0;35m%s\033[0m\n" "$(date +"%A, %d %b %Y, %I:%M %p")"
printf "  \\(__)|\n\n"

# init starship
eval "$(starship init bash)"