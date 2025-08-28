# ~/.bashrc
# by coalaura

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

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
	local target="${1:-.}"

	if [ ! -d "$target/.git" ]; then
		echo "$target is not a git repository"

		return 1
	fi

	git -C $target pull --rebase
}

# add, commit and push a given repo
function push() {
	local target="${1:-.}"

	if [ ! -d "$target/.git" ]; then
		printf "\033[33merror: $target is not a git repository\n"

		return 1
	fi

	if git -C "$target" diff-index --quiet HEAD --; then
		printf "\033[33merror: nothing to commit\n"

		return 0
	fi

	git -C $target status -sb

	local msg=""

	read -rp "message: " msg

	msg="$(echo "$msg" | xargs)"

	if [[ -z "$msg" ]]; then
		msg="update"
	fi

	git -C $target add -A
	git -C $target commit -am "$msg"
	git -C $target push
}

# convert https to ssh git repo
function git-ssh() {
	local target="${1:-.}"

	if [ ! -d "$target/.git" ]; then
		printf "\033[33merror: $target is not a git repository\n"

		return 1
	fi

	local url=$(git -C $target remote get-url origin)
	local ssh=$(echo $url | sed -E 's#https://github.com/([^/]+)/([^\.]+)(\.git)?#git@github.com:\1/\2.git#'))

	if [ $url -eq $ssh]; then
		printf "\033[33merror: already an ssh remote\n"

		return 1
	fi

	git -C $target remote set-url origin "$ssh"

	printf "\033[32msuccess: set remote to $ssh\n"
}

# print git remote origin
function origin() {
	local target="${1:-.}"

	if [ ! -d "$target/.git" ]; then
		printf "\033[33merror: $target is not a git repository\n"

		return 1
	fi

	echo "origin: $(git -C $target remote get-url origin)"
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
export PATH="$PATH:~/.bun/bin"

# ensure github ssh key is loaded
if [ -f ~/.ssh/keys/github ]; then
	ssh-add ~/.ssh/keys/github
fi

# print welcome message
printf " \\    /\\ \n"
printf "  )  ( ')  \033[0;32m$(hostname | tr -d '[:space:]')\033[0m\n"
printf " (  /  )   \033[0;35m$(date +"%A, %d %b %Y, %I:%M %p")\033[0m\n"
printf "  \\(__)|\n\n"

# init starship
eval "$(starship init bash)"