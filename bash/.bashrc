# ~/.bashrc
# by coalaura

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Show disk usage of current directory
function usage() {
    du -sh "${1:-.}" | sort -hr
}

# Find files/directories quickly
function ff() {
	find . -name "*$1*" -type f
}

function fd() {
	find . -name "*$1*" -type d
}

# perform maintenance and updates
function update() {
	(
		function print_time() {
			echo "[$(date '+%H:%M:%S')] - $1"
		}

		print_time "pacman -Syu"
        sudo pacman -Syu --noconfirm > /dev/null

		print_time "paru -Syu"
		paru -Syu --noconfirm > /dev/null

        print_time "pacman -Sc"
        sudo pacman -Sc --noconfirm > /dev/null

        print_time "pacman -Rns $(pacman -Qtdq)"
        readarray -t orphans < <(pacman -Qtdq 2>/dev/null)
		if (( ${#orphans[@]} )); then
			sudo pacman -Rns --noconfirm "${orphans[@]}" > /dev/null
		fi

		print_time "clean old logs"
		sudo find /var/log -type f -name "*.log" -mtime +14 -delete > /dev/null

		print_time "clean olg /tmp"
		sudo find /tmp -type f -atime +7 -delete > /dev/null

		print_time "clean olg /var/tmp"
		sudo find /var/tmp -type f -atime +7 -delete > /dev/null

		print_time "completed"
	)
}

# pull a given repo
function pull() {
	local target="$1"

	if [ -n "$target" ]; then
		(cd "$target" && git pull --rebase)
	else
		git pull --rebase
	fi
}

# add, commit and push a given repo
function push() {
	local target="${1:-.}"

	if [ ! -d "$target/.git" ]; then
		echo "$target is not a git repository."

		return 1
	fi

	(
		cd "$target" || return 1
		git add -A
		git commit -am "update"
		git push
	)
}

# Convert https to ssh git repo
function git-ssh() {
	git remote set-url origin "$(git remote get-url origin | sed -E 's#https://github.com/([^/]+)/([^\.]+)(\.git)?#git@github.com:\1/\2.git#')"
}

# Only show directories for cd completion
complete -d cd

# various aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
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
export HISTSIZE=50000
export HISTFILESIZE=100000

# path additions
export PATH="$PATH:~/.bun/bin"

# ensure github ssh key is loaded
if [ -f ~/.ssh/keys/github ]; then
	ssh-add ~/.ssh/keys/github
fi

# print welcome message
local hostname=$(hostname | tr -d '[:space:]')
local current_time=$(date +"%A, %d %b %Y, %I:%M %p")

printf " \\    /\\ \n"
printf "  )  ( ')  \033[0;32m${hostname}\033[0m\n"
printf " (  /  )   ${current_time}\n"
printf "  \\(__)|\n\n"

# init starship
eval "$(starship init bash)"