#!/bin/bash
# ~/.bashrc
# by coalaura

if [ -f "$HOME/.shenv" ]; then
    . "$HOME/.shenv"
fi

# If not running interactively, don't do anything
if [[ $- != *i* ]]; then
	return
fi

##
# TUI Helpers
##

function _print_info() {
	if [[ -z "$1" ]]; then
		echo ""
	else
		printf "\033[36m::\033[0m %s\n" "$1"
	fi
}

function _print_success() {
	printf "\033[32m::\033[0m %s\n" "$1"
}

function _print_error() {
	printf "\033[31m!!\033[0m %s\n" "$1"
}

function _print_sub() {
	printf "   \033[90m-> %s\033[0m\n" "$1"
}

function _read_line() {
	local prompt="$1"
	local var_name="$2"

	read -rp $'\033[33m??\033[0m '"$prompt" "$var_name"
}

##
# Helper Functions
##

# parse and validate arguments for build, run, test, vet, fix, bench
function _parse_args() {
	local cmd_name="$1"
	local allowed_langs=" $2 "
	local allow_os="$3"
	local allow_build_opts="$4"
	shift 4

	PARSED_LANG=""
	PARSED_OS=""
	PARSED_TARGET=""
	PARSED_OPTS=()
	PARSED_PASS=()

	local parsing_opts=true

	while (( $# > 0 )); do
		local arg="$1"

		if [[ "$parsing_opts" == true ]]; then
			case "$arg" in
				--)
					parsing_opts=false
					shift

					continue
					;;
				--pure|--compat|--min)
					if [[ "$allow_build_opts" == "1" ]]; then
						PARSED_OPTS+=("$arg")
						shift
					else
						_print_error "Unknown argument for $cmd_name: $arg"

						return 1
					fi
					;;
				win|windows|lin|linux|dar|darwin)
					if [[ "$allow_os" == "1" ]]; then
						case "${arg,,}" in
							win|windows) PARSED_OS="windows" ;;
							lin|linux)   PARSED_OS="linux" ;;
							dar|darwin)  PARSED_OS="darwin" ;;
						esac

						shift
					else
						_print_error "Unknown argument for $cmd_name: $arg"

						return 1
					fi
					;;
				*)
					local lower_arg="${arg,,}"

					if [[ $allowed_langs =~ " $lower_arg " ]]; then
						PARSED_LANG="$lower_arg"
						shift
					elif _looks_like_path "$arg" && [[ -z "$PARSED_TARGET" ]]; then
						PARSED_TARGET="$arg"
						shift
					else
						_print_error "Unknown argument for $cmd_name: $arg"

						return 1
					fi
					;;
			esac
		else
			PARSED_PASS+=("$arg")
			shift
		fi
	done
}

function _looks_like_path() {
	local token="$1"

	if [[ -z "$token" ]]; then
		return 1
	fi

	# "-" probably flag
	if [[ "$token" == -* ]]; then
		return 1
	fi

	# "./path" or "path/sub" or "path.go"
	if [[ "$token" =~ ^\.[/\\] ]] || [[ "$token" == */* || "$token" == *\\* ]] || [[ "$token" =~ \.[a-zA-Z0-9]+$ ]]; then
		return 0
	fi

	if [[ -e "$token" ]]; then
		return 0
	fi

	return 1
}

# automatically detect target project type based on files
function _detect_lang() {
	local cmd_name="$1"
	local target="$2"

	if [[ "$cmd_name" == "bench" || "$cmd_name" == "test" || "$cmd_name" == "run" || "$cmd_name" == "build" ]]; then
		if [[ -f "$target/${cmd_name}.sh" ]]; then
			echo "script"

			return
		fi
	fi

	if [[ "$cmd_name" == "run" && -f "$target/artisan" ]]; then
		echo "php"

		return
	fi

	if [[ -f "$target/go.mod" ]]; then
		echo "go"

		return
	fi

	if [[ -f "$target/package.json" ]]; then
		echo "js"

		return
	fi

	if [[ "$cmd_name" == "run" ]]; then
		for file in "index.js" "main.js" "app.js"; do
			if [[ -f "$target/$file" ]]; then
				echo "js"

				return
			fi
		done
	fi

	echo ""
}

# starts a timer
function _start_timer() {
	date +%s%3N 2>/dev/null || echo 0
}

# stops and prints a started timer
function _end_timer() {
	local start_time="$1"
	local action_name="${2:-built}"
	local end_time=$(_start_timer)

	if [[ "$start_time" != "0" && "$end_time" != "0" ]]; then
		local elapsed=$((end_time - start_time))

		if [[ $elapsed -lt 1000 ]]; then
			_print_sub "$action_name in ${elapsed}ms"
		else
			local sec=$(awk "BEGIN {printf \"%.2f\", $elapsed/1000}")

			_print_sub "$action_name in ${sec}s"
		fi
	else
		_print_sub "$action_name"
	fi
}

# get recent git tag preview lines
function _git_tag_lines() {
	local target="${1:-.}"
	local count="${2:-1}"

	git -C "$target" tag -n1 --sort=-creatordate | head -n "$count"
}

# print a parsed git tag preview line
function _print_tag_preview() {
	local label="$1"
	local line="$2"

	local tag_name="${line%%[[:space:]]*}"
	local tag_msg="${line#"$tag_name"}"

	tag_msg="$(echo "$tag_msg" | xargs)"

	if [[ -z "$tag_name" ]]; then
		tag_name="n/a"
	fi

	if [[ -z "$tag_msg" || "$tag_msg" == "$line" ]]; then
		tag_msg="(no tag message)"
	fi

	if [[ -n "$label" ]]; then
		_print_info "$label: $tag_name"
	else
		_print_info "$tag_name"
	fi

	_print_sub "$tag_msg"
}

# run go generate for a project
function _go_generate() {
	local target="${1:-.}"

	_print_info "[go] generating $target"

	local t0=$(_start_timer)

	if ! go -C "$target" generate ./...; then
		return 1
	fi

	_end_timer "$t0" "generated"
}

# setup Go build environment and parse custom flags
function _apply_go_env() {
	local target_os="${1:-linux}"
	local target_arch="${2:-amd64}"

	shift 2

	local is_pure=false
	local is_compat=false
	local is_min=false

	GO_EXTRA_ARGS=()

	local -a merged_tags=()
	local -A seen_tags=()

	_add_go_tags() {
		local tag_str="$1"
		local old_ifs="$IFS"
		local tag

		IFS=','

		for tag in $tag_str; do
			tag="$(echo "$tag" | xargs)"

			if [[ -z "$tag" ]]; then
				continue
			fi

			if [[ -z "${seen_tags[$tag]:-}" ]]; then
				seen_tags["$tag"]=1

				merged_tags+=("$tag")
			fi
		done

		IFS="$old_ifs"
	}

	while (( $# > 0 )); do
		case "$1" in
			--pure)
				is_pure=true
				;;
			--compat)
				is_compat=true
				;;
			--min)
				is_min=true
				;;
			-tags|--tags)
				if (( $# > 1 )); then
					_add_go_tags "$2"
					shift
				fi
				;;
			-tags=*|--tags=*)
				_add_go_tags "${1#*=}"
				;;
			*)
				GO_EXTRA_ARGS+=("$1")
				;;
		esac

		shift
	done

	export GOOS="$target_os"
	export GOARCH="$target_arch"
	export GO_MINIFY="$is_min"

	GO_BUILD_FLAGS=("-trimpath" "-buildvcs=false")
	GO_LDFLAGS="-s -w"

	if [[ "$is_pure" == "true" ]]; then
		export CGO_ENABLED=0

		_add_go_tags "netgo,osusergo"

		unset CC CXX CGO_CFLAGS CGO_CXXFLAGS CGO_LDFLAGS
	else
		export CGO_ENABLED=1
	fi

	GO_TAGS_ARGS=""

	if (( ${#merged_tags[@]} > 0 )); then
		GO_BUILD_FLAGS+=("-tags" "$(IFS=,; echo "${merged_tags[*]}")")
		GO_TAGS_ARGS="-tags $(IFS=,; echo "${merged_tags[*]}")"
	fi

	if [[ "$is_compat" == "true" ]]; then
		export GOAMD64=v1
	else
		export GOAMD64=v3
	fi

	# always-enabled go experiments
	local -a goexperiments=()
	local -A seen_exp=()

	_add_go_experiment() {
		local exp
		local old_ifs="$IFS"

		IFS=','

		for exp in $1; do
			exp="$(echo "$exp" | xargs)"

			if [[ -z "$exp" ]]; then
				continue
			fi

			if [[ -z "${seen_exp[$exp]:-}" ]]; then
				seen_exp["$exp"]=1
				goexperiments+=("$exp")
			fi
		done

		IFS="$old_ifs"
	}

	_add_go_experiment "${GOEXPERIMENT:-}"
	_add_go_experiment "runtimefreegc,newinliner"

	export GOEXPERIMENT="$(IFS=,; echo "${goexperiments[*]}")"

	GO_MODE_STR="cgo"

	if [[ "$is_pure" == "true" ]]; then
		GO_MODE_STR="pure"
	fi

	if [[ "$is_compat" == "true" ]]; then
		GO_MODE_STR="${GO_MODE_STR},compat"
	else
		GO_MODE_STR="${GO_MODE_STR},opt"
	fi

	if [[ "$is_min" == "true" ]]; then
		GO_MODE_STR="${GO_MODE_STR},min"
	fi

	if [[ "$CGO_ENABLED" == "1" ]]; then
		local zig_target=""
		local host_arch="$(go env GOHOSTARCH 2>/dev/null || uname -m)"

		case "$host_arch" in
			x86_64) host_arch="amd64" ;;
			aarch64) host_arch="arm64" ;;
		esac

		case "$target_os/$target_arch" in
			linux/amd64)   zig_target="x86_64-linux-musl" ;;
			linux/arm64)   zig_target="aarch64-linux-musl" ;;
			windows/amd64) zig_target="x86_64-windows-gnu" ;;
			windows/arm64) zig_target="aarch64-windows-gnu" ;;
			darwin/amd64)  zig_target="x86_64-macos-none" ;;
			darwin/arm64)  zig_target="aarch64-macos-none" ;;
		esac

		if [[ "$target_os" == "linux" || "$target_os" == "windows" ]]; then
			GO_LDFLAGS="$GO_LDFLAGS -linkmode external -extldflags=-static"
		fi

		local cc_cmd="zig cc"
		local cxx_cmd="zig c++"

		if [[ -n "$zig_target" ]]; then
			cc_cmd="$cc_cmd -target $zig_target"
			cxx_cmd="$cxx_cmd -target $zig_target"
		fi

		local arch_flag=""
		if [[ "$target_arch" == "amd64" ]]; then
			if [[ "$is_compat" == "true" ]]; then
				arch_flag="-march=x86_64"
			else
				arch_flag="-march=x86_64_v3"
			fi

			cc_cmd="$cc_cmd $arch_flag"
			cxx_cmd="$cxx_cmd $arch_flag"
		fi

		export CC="$cc_cmd"
		export CXX="$cxx_cmd"

		local opt_level="-O3"

		if [[ "$is_min" == "true" ]]; then
			opt_level="-Os"
		fi

		local cflags="-g0 $opt_level -ffunction-sections -fdata-sections"

		if [[ -n "$arch_flag" ]]; then
			cflags="$cflags $arch_flag"
		fi

		export CGO_CFLAGS="$cflags"
		export CGO_CXXFLAGS="$cflags"
		export CGO_LDFLAGS="-Wl,--gc-sections"
	fi
}

##
# Path Completions
##

declare -A _FILTER_COMPLETIONS_EXT

function _case_insensitive_paths() (
	local mode="$1"
	local word="$2"
	local path="" quote="" character next
	local index

	# COMP_WORDS retains shell quoting; decode it without evaluating shell code.
	for (( index = 0; index < ${#word}; index++ )); do
		character="${word:index:1}"

		if [[ "$character" == "$quote" && -n "$quote" ]]; then
			quote=""
		elif [[ -z "$quote" && ( "$character" == "'" || "$character" == '"' ) ]]; then
			quote="$character"
		elif [[ "$character" == '\' && "$quote" != "'" ]]; then
			next="${word:index+1:1}"

			if [[ -n "$next" && ( -z "$quote" || "$next" == ['$`"\'] ) ]]; then
				path+="$next"
				((index++))
			else
				path+="$character"
			fi
		else
			path+="$character"
		fi
	done

	if [[ "$word" == '~/'* ]]; then
		path="$HOME/${path:2}"
	fi

	local pattern="" match

	# Every component needs a glob pattern: nocaseglob alone cannot fix literal parents.
	for (( index = 0; index < ${#path}; index++ )); do
		character="${path:index:1}"

		case "$character" in
			[[:alpha:]]) pattern+="[${character,,}${character^^}]" ;;
			/) pattern+="/" ;;
			*) pattern+="\\$character" ;;
		esac
	done

	local IFS=""

	unset GLOBIGNORE
	set +f

	shopt -u failglob dotglob
	shopt -s nullglob

	for match in $pattern*; do
		if [[ "$mode" != "directory" || -d "$match" ]]; then
			printf '%s\0' "$match"
		fi
	done
)

function _path_complete() {
	mapfile -d '' -t COMPREPLY < <(_case_insensitive_paths file "${COMP_WORDS[COMP_CWORD]}")
}

function _directory_complete() {
	mapfile -d '' -t COMPREPLY < <(_case_insensitive_paths directory "${COMP_WORDS[COMP_CWORD]}")
}

function _filtered_file_complete() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local cmd="${COMP_WORDS[0]}"

	COMPREPLY=()

	local exts="${_FILTER_COMPLETIONS_EXT[$cmd]}"

	if [[ -z "$exts" ]]; then
		_path_complete

		return 0
	fi

	local -a ext_arr=()
	local old_ifs="$IFS"
	IFS=','
	read -ra ext_arr <<< "$exts"
	IFS="$old_ifs"

	local -a matches=()

	# include directories for navigation and filter files by extension
	while IFS= read -r -d '' file; do
		if [[ -d "$file" ]]; then
			matches+=("$file")

			continue
		fi

		local ext="${file##*.}"
		local base="${file##*/}"

		if [[ "$ext" == "$base" ]]; then
			continue
		fi

		for valid_ext in "${ext_arr[@]}"; do
			if [[ "${ext,,}" == "${valid_ext,,}" ]]; then
				matches+=("$file")

				break
			fi
		done
	done < <(_case_insensitive_paths file "$cur")

	COMPREPLY=("${matches[@]}")

	return 0
}

function filter_completions() {
	local cmd="$1"
	shift

	local exts=""
	local ext

	for ext in "$@"; do
		if [[ -n "$exts" ]]; then
			exts+=","
		fi

		exts+="$ext"
	done

	_FILTER_COMPLETIONS_EXT[$cmd]="$exts"

	complete -o filenames -F _filtered_file_complete "$cmd"
}

##
# Command Not Found
##

# handle .command shorthand for local executables
function command_not_found_handle() {
	local cmd="$1"

	shift

	if [[ "$cmd" =~ ^\.([a-zA-Z0-9_-]+)$ ]]; then
		local name="${BASH_REMATCH[1]}"

		# .sh files first (run with bash)
		if [[ -f "./${name}.sh" ]]; then
			_print_info "running ./${name}.sh"

			bash "./${name}.sh" "$@"

			return $?
		fi

		# executable without extension
		if [[ -f "./${name}" && -x "./${name}" ]]; then
			_print_info "running ./${name}"

			"./${name}" "$@"

			return $?
		fi

		_print_error "no executable found for .${name}"

		return 127
	fi

	# system handler (if it exists)
	if declare -f _command_not_found_handle >/dev/null 2>&1; then
		_command_not_found_handle "$cmd" "$@"

		return $?
	fi

	# default behavior
	printf "bash: %s: command not found\n" "$cmd"

	return 127
}

##
# Reset exit code
##

__last_histcmd=""

__reset_exit_code() {
	local status=$?

	if [[ -n ${__last_histcmd+x} && $HISTCMD == "$__last_histcmd" ]]; then
		# no new command run
		return 0
	fi

	__last_histcmd=$HISTCMD

	return "$status"
}

##
# Commands
##

# git root detector
function git_root() {
	local path="${1:-.}"

	git -C "$path" rev-parse --show-toplevel 2>/dev/null || echo "$path"
}

# check nginx config and restart
function ngx() {
	nginx -t && service nginx restart
}

# perform system maintenance and updates
# perform system maintenance and updates
function update() {
	(
		set +e
		set -uo pipefail

		local failed=0
		local prune_containers=false
		local use_color=false
		local active_step=""
		local package_operation=false

		if [[ -t 1 && "${TERM:-dumb}" != "dumb" && -z "${NO_COLOR:-}" ]]; then
			use_color=true
		fi

		function print_time() {
			if [[ "$use_color" == true ]]; then
				printf "\033[90m[\033[0m\033[36m%s\033[0m\033[90m] ->\033[0m %s\n" "$(date '+%H:%M:%S')" "$1"
			else
				printf '[%s] -> %s\n' "$(date '+%H:%M:%S')" "$1"
			fi
		}

		function get_space() {
			df --output=used -B1 / | tail -n1 | xargs
		}

		function run_root() {
			if (( EUID == 0 )); then
				"$@"
			else
				sudo "$@"
			fi
		}

		function stop_update() {
			local status="$1"
			local reason="$2"

			print_time "$reason${active_step:+ ($active_step)}"

			if [[ "$package_operation" == true ]]; then
				print_time "package operation incomplete; verify the update and boot files before rebooting"
			fi

			exit "$status"
		}

		function run_step() {
			local label="$1"
			shift

			active_step="$label"

			print_time "$label"

			local status

			# keep stdin, stdout and stderr attached to the caller
			"$@"
			status=$?

			if (( status == 130 )); then
				stop_update "$status" "interrupted"
			elif (( status == 143 )); then
				stop_update "$status" "terminated"
			fi

			if (( status != 0 )); then
				((failed += 1))

				print_time "$label failed (exit $status)"
			fi

			active_step=""

			return "$status"
		}

		function update_env() {
			(
				cd "$1" || exit 1

				bash setup.sh
			)
		}

		function remove_orphans() {
			local output status
			local -a orphans=()

			output=$(pacman -Qtdq 2>&1)
			status=$?

			if (( status == 1 )) && [[ -z "$output" ]]; then
				return 0
			fi

			if (( status != 0 )); then
				printf '%s\n' "$output" >&2

				return "$status"
			fi

			if [[ -n "$output" ]]; then
				readarray -t orphans <<< "$output"

				run_root pacman -Rns --noconfirm "${orphans[@]}"
			fi
		}

		function check_boot_files() {
			(
				set +u
				shopt -s nullglob

				local problems=0
				local target kernel package file preset variable value
				local -a presets=(/etc/mkinitcpio.d/*.preset)
				local -a kernels=(/usr/lib/modules/*/pkgbase)

				if (( ${#presets[@]} == 0 && ${#kernels[@]} == 0 )); then
					printf '%s\n' "boot-file check skipped (no mkinitcpio presets or installed kernels)"

					return 0
				fi

				# separate boot filesystems must be mounted before checking or updating
				local targets
				targets=$(findmnt --fstab --raw --noheadings --output TARGET) || return 1

				while IFS= read -r target; do
					case "$target" in
						/boot|/boot/efi|/efi)
							if ! mountpoint -q "$target"; then
								printf 'boot filesystem is not mounted: %s\n' "$target"

								return 1
							fi
							;;
					esac
				done <<< "$targets"

				# an interrupted kernel upgrade can remove the preset itself
				for kernel in "${kernels[@]}"; do
					package=$(< "$kernel")

					if [[ ! -s "${kernel%/*}/vmlinuz" ]]; then
						printf 'missing kernel image: %s/vmlinuz\n' "${kernel%/*}"
						((problems += 1))
					fi

					if [[ ! -s "/etc/mkinitcpio.d/$package.preset" ]]; then
						printf 'missing kernel preset: /etc/mkinitcpio.d/%s.preset\n' "$package"
						((problems += 1))
					fi
				done

				for file in "${presets[@]}"; do
					(
						# presets are shell configuration; isolate each one
						PRESETS=()
						ALL_kver=""

						source "$file" || exit 1

						if (( ${#PRESETS[@]} == 0 )); then
							printf 'no enabled presets: %s\n' "$file"

							exit 1
						fi

						local missing=0

						for preset in "${PRESETS[@]}"; do
							variable="${preset}_kver"
							value="${!variable:-${ALL_kver:-}}"

							if [[ "$value" != "none" && "$value" != /* ]]; then
								value="/usr/lib/modules/$value/vmlinuz"
							fi

							if [[ "$value" != "none" && ! -s "$value" ]]; then
								printf 'missing kernel for %s (%s): %s\n' "$file" "$preset" "$value"
								missing=1
							fi

							local outputs=0

							for variable in "${preset}_image" "${preset}_uki"; do
								value="${!variable:-}"

								if [[ -z "$value" ]]; then
									continue
								fi

								((outputs += 1))

								if [[ ! -s "$value" ]]; then
									printf 'missing boot image for %s (%s): %s\n' "$file" "$preset" "$value"
									missing=1
								fi
							done

							if (( outputs == 0 )); then
								printf 'no boot image configured: %s (%s)\n' "$file" "$preset"
								missing=1
							fi
						done

						exit "$missing"
					) || ((problems += 1))
				done

				if (( problems > 0 )); then
					return 1
				fi

				printf '%s\n' "configured kernel and initramfs/UKI files are present"
			)
		}

		if (( $# > 1 )) || [[ "${1:-}" != "" && "${1:-}" != "--prune-containers" ]]; then
			print_time "usage: update [--prune-containers]"

			return 2
		fi

		if [[ "${1:-}" == "--prune-containers" ]]; then
			prune_containers=true
		fi

		trap 'stop_update 130 "interrupted"' INT
		trap 'stop_update 143 "terminated"' TERM

		if (( EUID != 0 )); then
			sudo -v || return 1
		fi

		local used_before="" used_after=""

		used_before=$(get_space) || used_before=""

		##
		# env update
		##

		local env_dir=""

		if [[ -n "${USERPROFILE:-}" && -d "$USERPROFILE/env" ]]; then
			env_dir="$USERPROFILE/env"
		elif [[ -d "$HOME/env" ]]; then
			env_dir="$HOME/env"
		fi

		if [[ -n "$env_dir" ]]; then
			run_step "env update ($env_dir)" update_env "$env_dir"
		fi

		##
		# arch (pacman, paru, yay)
		##

		if command -v pacman &> /dev/null; then
			local arch_status=0
			local check_boot=false

			if command -v mkinitcpio &> /dev/null && [[ -z "${WSL_INTEROP:-}${WSL_DISTRO_NAME:-}" ]]; then
				check_boot=true

				if ! run_step "mkinitcpio boot files (before update)" run_root bash -c "$(declare -f check_boot_files); check_boot_files"; then
					print_time "update stopped; repair the boot files or mounts before continuing"

					return 1
				fi
			fi

			package_operation=true

			if (( EUID != 0 )) && command -v paru &> /dev/null; then
				run_step "paru -syu" paru -Syu --noconfirm || arch_status=$?
			elif (( EUID != 0 )) && command -v yay &> /dev/null; then
				run_step "yay -syu" yay -Syu --noconfirm || arch_status=$?
			else
				run_step "pacman -syu" run_root pacman -Syu --noconfirm || arch_status=$?

				if command -v paru &> /dev/null || command -v yay &> /dev/null; then
					print_time "AUR update skipped (running as root)"
				fi
			fi

			if (( arch_status != 0 )); then
				print_time "pacman cleanup skipped (update failed)"
				print_time "update stopped; verify the package transaction and boot files before rebooting"

				return "$arch_status"
			fi

			run_step "pacman -rns (orphans)" remove_orphans || arch_status=$?

			# verify boot files before pruning packages that may be needed for recovery
			if [[ "$check_boot" == true ]]; then
				if ! run_step "mkinitcpio boot files" run_root bash -c "$(declare -f check_boot_files); check_boot_files"; then
					print_time "update stopped; repair the boot files before rebooting"

					return 1
				fi
			fi

			if (( arch_status != 0 )); then
				print_time "pacman cache cleanup skipped (orphan removal failed)"

				return "$arch_status"
			fi

			package_operation=false

			if command -v paccache &> /dev/null; then
				run_step "paccache -rk2" run_root paccache -rk2
				run_step "paccache -ruk0" run_root paccache -ruk0
			else
				run_step "pacman -sc" run_root pacman -Sc --noconfirm
			fi
		fi

		##
		# debian (apt)
		##

		if command -v apt-get &> /dev/null; then
			package_operation=true

			if run_step "apt update" run_root apt-get update --error-on=any -qq; then
				if run_step "apt full-upgrade" run_root env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq; then
					if run_step "apt autoremove" run_root env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y -qq; then
						run_step "apt clean" run_root apt-get clean -qq
					else
						print_time "apt clean skipped (autoremove failed)"

						return 1
					fi
				else
					print_time "apt cleanup skipped (upgrade failed)"

					return 1
				fi
			else
				print_time "apt upgrade and cleanup skipped (update failed)"

				return 1
			fi
		fi

		package_operation=false

		##
		# other (flatpak, snap)
		##

		if command -v flatpak &> /dev/null; then
			if run_step "flatpak update" flatpak update -y; then
				run_step "flatpak uninstall unused" flatpak uninstall --unused -y
			else
				print_time "flatpak cleanup skipped (update failed)"
			fi
		fi

		if command -v snap &> /dev/null; then
			run_step "snap refresh" run_root snap refresh
		fi

		##
		# docker
		##

		if command -v docker &> /dev/null; then
			local endpoint=""
			local -a docker_cmd=(docker)

			if [[ -n "${DOCKER_CONTEXT:-}" ]]; then
				endpoint=$(docker context inspect "$DOCKER_CONTEXT" --format '{{.Endpoints.docker.Host}}' 2>/dev/null)
			elif [[ -n "${DOCKER_HOST:-}" ]]; then
				endpoint="$DOCKER_HOST"
			else
				endpoint=$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null)
			fi

			if [[ "$endpoint" == unix://* ]]; then
				if ! docker info > /dev/null 2>&1 && [[ "$endpoint" == "unix:///var/run/docker.sock" || "$endpoint" == "unix:///run/docker.sock" ]]; then
					docker_cmd=(run_root env -u DOCKER_CONTEXT -u DOCKER_HOST docker --host "$endpoint")
				fi

				if "${docker_cmd[@]}" info > /dev/null 2>&1; then
					run_step "docker image prune" "${docker_cmd[@]}" image prune --force
					run_step "docker builder prune" "${docker_cmd[@]}" builder prune --force --filter until=168h --keep-storage 10GB

					if [[ "$prune_containers" == true ]]; then
						run_step "docker container prune" "${docker_cmd[@]}" container prune --force
						run_step "docker network prune" "${docker_cmd[@]}" network prune --force
					fi
				else
					print_time "docker cleanup skipped (daemon unavailable)"
				fi
			else
				print_time "docker cleanup skipped (remote or unknown endpoint)"
			fi
		fi

		##
		# logs & temp
		##

		if [[ -d /run/systemd/system ]] && command -v journalctl &> /dev/null; then
			run_step "journalctl vacuum" run_root journalctl --rotate --vacuum-time=14d
		fi

		if command -v logrotate &> /dev/null && [[ -f /etc/logrotate.conf ]]; then
			run_step "logrotate" run_root logrotate /etc/logrotate.conf
		fi

		if command -v systemd-tmpfiles &> /dev/null; then
			run_step "clean old temp files" run_root systemd-tmpfiles --clean
		fi

		##
		# health checks
		##

		if command -v needrestart &> /dev/null; then
			run_step "needrestart" run_root needrestart -r l
		fi

		if command -v pacman &> /dev/null && command -v pacdiff &> /dev/null; then
			run_step "pacdiff (pending configuration files)" run_root pacdiff -o
		fi

		if ! command -v pacman &> /dev/null && command -v dpkg &> /dev/null; then
			run_step "dpkg audit" run_root dpkg --audit
		fi

		if [[ -d /run/systemd/system ]] && command -v systemctl &> /dev/null; then
			run_step "systemctl failed services" systemctl --failed --no-legend --no-pager
		fi

		if [[ -f /run/reboot-required ]]; then
			print_time "reboot required"
		fi

		##
		# summary
		##

		used_after=$(get_space) || used_after=""

		local summary="completed"

		if (( failed > 0 )); then
			summary="completed with $failed failed step(s)"
		fi

		if [[ "$used_before" =~ ^[0-9]+$ && "$used_after" =~ ^[0-9]+$ ]]; then
			local freed=$((used_before - used_after))
			local freed_human="" used_human=""

			if (( freed > 0 )); then
				freed_human=$(numfmt --to=iec "$freed" 2>/dev/null || echo "${freed}B")

				print_time "$summary (root filesystem: $freed_human less used)"
			elif (( freed < 0 )); then
				used_human=$(numfmt --to=iec "$(( -freed ))" 2>/dev/null || echo "$(( -freed ))B")

				print_time "$summary (root filesystem: $used_human more used)"
			else
				print_time "$summary"
			fi
		else
			print_time "$summary (disk usage unavailable)"
		fi

		if (( failed > 0 )); then
			return 1
		fi

		return 0
	)
}

# restart docker compose project in current directory (stop, pull, up -d)
function dcr() {
	local compose_file="$(find . -maxdepth 1 -name "compose.yml" -o -name "compose.yaml" -o -name "docker-compose.yml" -o -name "docker-compose.yaml" | head -1)"

	if [[ -z "$compose_file" ]]; then
		_print_error "no compose file"

		return 1
	fi

	_print_info "pulling $compose_file"

	docker compose -f "$compose_file" down && docker compose -f "$compose_file" pull && docker compose -f "$compose_file" up -d
}

# pull a given repo
function pull() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		_print_info "pulling $target"

		git -C "$target" pull --rebase
	)
}

# add, commit and push a given repo
function push() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		_print_info "checking $target"

		git -C "$target" add -A

		if git -C "$target" diff-index --quiet HEAD -- 2>/dev/null; then
			_print_error "nothing to commit"

			return 0
		fi

		git -C "$target" status -sb

		local msg

		_read_line "message: " msg

		msg="$(echo "$msg" | xargs)"

		if [[ -z "$msg" ]]; then
			msg="update"
		fi

		_print_info "pushing $target"

		git -C "$target" commit -m "$msg"
		git -C "$target" push
	)
}

# create and push a git tag
function tag() {
	(
		set -euo pipefail

		local target="$(git_root "${1:-.}")"

		if [[ ! -d "$target/.git" ]]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local latest_line="$(_git_tag_lines "$target" 1)"

		if [[ -n "$latest_line" ]]; then
			_print_tag_preview "current" "$latest_line"

			local last_tag="${latest_line%%[[:space:]]*}"

			if [[ -z "$(git -C "$target" log -1 --format='%h' "$last_tag..HEAD")" ]]; then
				_print_error "no new commits since $last_tag"

				return 1
			fi

			_print_info "commits:"

			while IFS= read -r commit; do
				_print_sub "$commit"
			done < <(git -C "$target" log --format='%h %s' "$last_tag..HEAD")
		else
			_print_info "current: n/a"

			if [[ -z "$(git -C "$target" log -1 --format='%h' HEAD)" ]]; then
				_print_error "no commits to tag"

				return 1
			fi

			_print_info "commits:"

			while IFS= read -r commit; do
				_print_sub "$commit"
			done < <(git -C "$target" log --format='%h %s' HEAD)
		fi

		_print_info ""

		local tag_name
		local msg

		_read_line "new tag: " tag_name

		tag_name="$(echo "$tag_name" | xargs)"

		if [[ -z "$tag_name" ]]; then
			_print_error "tag name is required"

			return 1
		fi

		_read_line "message: " msg

		msg="$(echo "$msg" | xargs)"

		if [[ -z "$msg" ]]; then
			_print_error "message is required"

			return 1
		fi

		_print_info "tagging $target as $tag_name"

		if ! git -C "$target" tag -a "$tag_name" -m "$msg"; then
			_print_error "failed to create tag"

			return 1
		fi

		_print_info "pushing tag $tag_name"

		if ! git -C "$target" push origin "$tag_name"; then
			_print_error "failed to push tag"

			return 1
		fi

		_print_success "tagged and pushed $tag_name"
	)
}

# delete and push-delete a git tag
function dtag() {
	(
		set -euo pipefail

		local target="$(git_root "${1:-.}")"

		if [[ ! -d "$target/.git" ]]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local latest_line="$(_git_tag_lines "$target" 1)"

		if [[ -z "$latest_line" ]]; then
			_print_error "no tags found"

			return 1
		fi

		_print_tag_preview "current" "$latest_line"

		_print_info ""

		local tag_name

		_read_line "delete tag: " tag_name

		tag_name="$(echo "$tag_name" | xargs)"

		if [[ -z "$tag_name" ]]; then
			_print_error "tag name is required"

			return 1
		fi

		_print_info "deleting $tag_name from $target"

		if ! git -C "$target" push origin ":refs/tags/$tag_name"; then
			_print_error "failed to delete remote tag"

			return 1
		fi

		if ! git -C "$target" tag -d "$tag_name"; then
			_print_error "failed to delete local tag"

			return 1
		fi

		_print_success "deleted and pushed $tag_name"
	)
}

# delete, recreate, and push a git tag
function rtag() {
	(
		set -euo pipefail

		local target="$(git_root "${1:-.}")"

		if [[ ! -d "$target/.git" ]]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local latest_line="$(_git_tag_lines "$target" 1)"

		if [[ -z "$latest_line" ]]; then
			_print_error "no tags found"

			return 1
		fi

		_print_tag_preview "current" "$latest_line"

		_print_info ""

		local tag_name

		_read_line "re-tag: " tag_name

		tag_name="$(echo "$tag_name" | xargs)"

		if [[ -z "$tag_name" ]]; then
			_print_error "tag name is required"

			return 1
		fi

		# get existing tag message
		local msg="$(git -C "$target" tag -l --format='%(contents:subject)' "$tag_name" | xargs)"

		if [[ -z "$msg" ]]; then
			msg="update $tag_name"
		fi

		_print_info "deleting $tag_name from $target"

		if ! git -C "$target" push origin ":refs/tags/$tag_name"; then
			_print_error "failed to delete remote tag"

			return 1
		fi

		if ! git -C "$target" tag -d "$tag_name"; then
			_print_error "failed to delete local tag"

			return 1
		fi

		_print_info "tagging $target as $tag_name"

		if ! git -C "$target" tag -a "$tag_name" -m "$msg"; then
			_print_error "failed to create tag"

			return 1
		fi

		_print_info "pushing tag $tag_name"

		if ! git -C "$target" push origin "$tag_name"; then
			_print_error "failed to push tag"

			return 1
		fi

		_print_success "re-tagged and pushed $tag_name"
	)
}

# list recent tags with first message lines
function tags() {
	(
		set -euo pipefail

		local target="$(git_root "${1:-.}")"

		if [[ ! -d "$target/.git" ]]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local -a lines=()

		readarray -t lines < <(_git_tag_lines "$target" 5)

		if (( ${#lines[@]} == 0 )); then
			_print_error "no tags found"

			return 1
		fi

		local line

		for line in "${lines[@]}"; do
			_print_tag_preview "" "$line"
			_print_info ""
		done
	)
}

# print git remote origin
function origin() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local url=$(git -C "$target" remote get-url origin 2>/dev/null)

		if [[ -z "$url" ]]; then
			_print_error "failed to get remote"

			return 1
		fi

		_print_info "origin: $url"
	)
}

# reset and cleans git repo
function trash() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local confirm

		_read_line "trash everything in $(basename "$target")? [y/N] " confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			_print_info "aborted"

			return 1
		fi

		_print_info "aborting pending operations..."

		git -C "$target" rebase --abort 2>/dev/null || true
		git -C "$target" merge --abort 2>/dev/null || true
		git -C "$target" cherry-pick --abort 2>/dev/null || true
		git -C "$target" bisect reset 2>/dev/null || true

		_print_info "resetting..."

		git -C "$target" reset --hard

		_print_info "cleaning..."

		git -C "$target" clean -fd

		_print_success "cleaned"
	)
}

# convert https to ssh git repo
function git_ssh() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			_print_error "$target is not a git repository"

			return 1
		fi

		local http=$(git -C "$target" remote get-url origin 2>/dev/null)

		if [[ -z "$http" ]]; then
			_print_error "failed to get remote"

			return 1
		fi

		if [[ ! "$http" =~ \.git$ ]]; then
			http="${http}.git"
		fi

		local ssh=$(echo "$http" | sed -E 's#^https://github\.com/([^/]+)/(.+)\.git#git@github.com:\1/\2.git#')

		if [[ "$http" == "$ssh" ]]; then
			_print_error "already an ssh remote"

			return 1
		fi

		git -C "$target" remote set-url origin "$ssh"

		_print_success "set remote to $ssh"
	)
}

# profile a project
function profile() (
	(
		set -euo pipefail

		local target="$(realpath ".")"
		local -a extra_args=("$@")
		local focus=""

		# If the first argument exists and doesn't start with '-', it's a focus keyword
		if (( ${#extra_args[@]} > 0 )) && [[ "${extra_args[0]}" != -* ]]; then
			focus="${extra_args[0]}"
			extra_args=("${extra_args[@]:1}")
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			rm -rf .profile && mkdir -p .profile

			_go_generate "$target"
			_apply_go_env "linux" "amd64" "${extra_args[@]}"

			if [[ -n "$focus" ]]; then
				_print_info "[go] profiling $target (focus: $focus, mode: $GO_MODE_STR)"

				go build -gcflags="-m -m" ./... 2>&1 | grep -i "$focus" > .profile/escape_analysis.txt || true
				go build -gcflags="-d=ssa/check_bce/debug=1" ./... 2>&1 | grep -i "$focus" > .profile/bce.txt || true
			else
				_print_info "[go] profiling $target (mode: $GO_MODE_STR)"

				go build -gcflags="-m" ./... > .profile/escape_analysis.txt 2>&1 || true
				go build -gcflags="-d=ssa/check_bce/debug=1" ./... > .profile/bce.txt 2>&1 || true
			fi

			go test -run=^$ -bench=. -benchmem \
				-cpuprofile=.profile/cpu.prof \
				-memprofile=.profile/mem.prof \
				-mutexprofile=.profile/mutex.prof \
				-blockprofile=.profile/block.prof \
				-goroutineleakprofile=.profile/goroutineleak.prof \
				-trace=.profile/trace.out \
				$GO_TAGS_ARGS "${GO_EXTRA_ARGS[@]}" ./... > .profile/bench.txt 2>&1 || true

			_print_success "profile complete"
			_print_sub "escape/inline: .profile/escape_analysis.txt"
			_print_sub "bce misses:    .profile/bce.txt"
			_print_sub "benchmarks:    .profile/bench.txt"
			_print_sub "cpu profile:   go tool pprof -http=:8080 .profile/cpu.prof"
			_print_sub "mem profile:   go tool pprof -http=:8081 .profile/mem.prof"
			_print_sub "mutex blocks:  go tool pprof -http=:8082 .profile/mutex.prof"
			_print_sub "goroutine leaks: go tool pprof -http=:8083 .profile/goroutineleak.prof"
			_print_sub "trace ui:      go tool trace .profile/trace.out"

			return
		fi

		_print_error "$target is not a recognized profile project"
	)
)

# auto-fix/lint a project
function fix() (
	(
		set -euo pipefail

		_parse_args "fix" "go js" 0 0 "$@" || return 1

		local target_lang="$PARSED_LANG"
		local -a pass_args=("${PARSED_PASS[@]}")
		local target="$(realpath ".")"

		if [[ -z "$target_lang" ]]; then
			target_lang=$(_detect_lang "fix" "$target")
		fi

		case "$target_lang" in
			go)
				_print_info "[go] fixing $target"

				go fix "${pass_args[@]}" ./...
				go fmt "${pass_args[@]}" ./...
				;;
			js)
				_print_info "[biome] fixing $target"

				biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path="$HOME/biome.json" "${pass_args[@]}"
				;;
			*)
				_print_error "unknown or undetected project type to fix"

				return 1
				;;
		esac
	)
)

# update a go project
function goup() {
	(
		set -euo pipefail

		local target="${1:-.}"

		target=$(realpath "$target")

		if [ ! -f "$target/go.mod" ]; then
			_print_error "$target is not a go project"

			return 1
		fi

		go -C "$target" get -u ./...

		go -C "$target" mod tidy

		_print_success "updated packages"
	)
}

# set the lowest Go version supported by a project
function gover() {
	(
		set -euo pipefail

		local target="${1:-.}"

		target=$(realpath "$target")

		if [[ ! -f "$target/go.mod" ]]; then
			_print_error "$target is not a go project"

			return 1
		fi

		local host_version="$(go env GOVERSION)"
		local host_minor="${host_version#go1.}"

		host_minor="${host_minor%%.*}"

		local temp_dir="$(mktemp -d)"
		local committed=false
		local had_sum=false

		cp "$target/go.mod" "$temp_dir/go.mod"

		if [[ -f "$target/go.sum" ]]; then
			cp "$target/go.sum" "$temp_dir/go.sum"
			had_sum=true
		fi

		function restore_go_mod() {
			cp "$temp_dir/go.mod" "$target/go.mod"

			if [[ "$had_sum" == true ]]; then
				cp "$temp_dir/go.sum" "$target/go.sum"
			else
				command rm -f "$target/go.sum"
			fi
		}

		function cleanup_gover() {
			if [[ "$committed" != true ]]; then
				restore_go_mod
			fi

			command rm -rf "$temp_dir"
		}

		trap cleanup_gover EXIT

		local -A seen_versions=()
		local -a versions=()
		local minor

		for (( minor = 11; minor <= host_minor; minor++ )); do
			seen_versions["1.$minor"]=1
		done

		while IFS= read -r version; do
			version="${version#go}"

			if [[ "$version" =~ ^1\.[0-9]+(\.[0-9]+)?$ ]]; then
				seen_versions["$version"]=1
			fi
		done < <(GOWORK=off GOTOOLCHAIN=local go -C "$target" list -m -f '{{.GoVersion}}' all 2>/dev/null || true)

		readarray -t versions < <(printf '%s\n' "${!seen_versions[@]}" | sort -V)

		local log_file="$temp_dir/check.log"

		local -A legacy_toolchains=(
			[11]="go1.11.13"
			[12]="go1.12.17"
			[13]="go1.13.15"
			[14]="go1.14.15"
			[15]="go1.15.15"
			[16]="go1.16.15"
			[17]="go1.17.13"
			[18]="go1.18.10"
			[19]="go1.19.13"
			[20]="go1.20.14"
		)

		local version

		_print_info "finding minimum Go version for $target"

		for version in "${versions[@]}"; do
			restore_go_mod

			if ! GOWORK=off GOTOOLCHAIN=local go -C "$target" mod edit -go="$version" >"$log_file" 2>&1; then
				continue
			fi

			if ! GOWORK=off GOTOOLCHAIN=local go -C "$target" mod tidy -go="$version" >>"$log_file" 2>&1; then
				continue
			fi

			minor="${version#1.}"
			minor="${minor%%.*}"

			if (( minor < 21 )); then
				if ! GOWORK=off GOTOOLCHAIN="${legacy_toolchains[$minor]}" go -C "$target" vet ./... >>"$log_file" 2>&1; then
					continue
				fi
			else
				if ! GOWORK=off GOTOOLCHAIN=local go -C "$target" vet -stdversion ./... >>"$log_file" 2>&1; then
					continue
				fi
			fi

			committed=true

			_print_success "set minimum Go version to $version"

			return 0
		done

		_print_error "could not determine a compatible Go version up to ${host_version#go}"

		if [[ -s "$log_file" ]]; then
			while IFS= read -r line; do
				_print_sub "$line"
			done < "$log_file"
		fi

		return 1
	)
}

# show TCP listeners and UDP bound sockets by port or process name
function listen() (
	local query="${1:-}"

	if (( $# != 1 )) || [[ -z "$query" ]]; then
		_print_error "usage: listen <port|name>"

		return 1
	fi

	if ! command -v ss >/dev/null 2>&1; then
		_print_error "ss is required"

		return 1
	fi

	local target_port=""
	local target_name=""

	if [[ "$query" =~ ^[0-9]+$ ]]; then
		target_port="${query#"${query%%[!0]*}"}"
		target_port="${target_port:-0}"

		if (( ${#target_port} > 5 )) || (( target_port < 1 || target_port > 65535 )); then
			_print_error "invalid port '$query'"

			return 1
		fi
	else
		target_name="${query,,}"
	fi

	local sockets

	if ! sockets="$(ss -H -O -lntup)"; then
		_print_error "failed to list sockets"

		return 1
	fi

	local protocol state recvq sendq address peer owners port remaining name pid line
	local owner_pattern='"([^"]+)",pid=([0-9]+)'
	local -a matches=()

	while IFS= read -r line; do
		read -r protocol state recvq sendq address peer owners <<< "$line"

		if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
			continue
		fi

		port="${address##*:}"

		if [[ ! "$port" =~ ^[0-9]+$ ]]; then
			continue
		fi

		if [[ -n "$target_port" && "$port" != "$target_port" ]]; then
			continue
		fi

		remaining="$owners"
		local has_owner=false

		while [[ "$remaining" =~ $owner_pattern ]]; do
			name="${BASH_REMATCH[1]}"
			pid="${BASH_REMATCH[2]}"

			remaining="${remaining#*"${BASH_REMATCH[0]}"}"
			has_owner=true

			if [[ -z "$target_name" || "${name,,}" == *"$target_name"* ]]; then
				matches+=("$port"$'\t'"${protocol^^}"$'\t'"$address"$'\t'"$pid"$'\t'"$name")
			fi
		done

		if [[ -n "$target_port" && "$has_owner" == false ]]; then
			matches+=("$port"$'\t'"${protocol^^}"$'\t'"$address"$'\t'"-"$'\t'"(unknown)")
		fi
	done <<< "$sockets"

	if (( ${#matches[@]} == 0 )); then
		if [[ -n "$target_port" ]]; then
			_print_error "no TCP/UDP listeners on port $target_port"
		else
			_print_error "no TCP/UDP listeners for '$query'"
		fi

		return 1
	fi

	if [[ -n "$target_port" ]]; then
		_print_info "listening on :$target_port"
	else
		_print_info "listeners matching '$query'"
	fi

	local summary

	printf '%s\n' "${matches[@]}" | LC_ALL=C sort -t $'\t' -k1,1n -k2,2 -k3,3 -k4,4n -k5,5 -u | while IFS=$'\t' read -r port protocol address pid name; do
		printf -v summary '%-3s %-35s %6s  %s' "$protocol" "$address" "$pid" "$name"

		_print_sub "$summary"
	done
)

# create an ssh tunnel for a specific port
function tunnel() {
	(
		set -euo pipefail

		local host="${1:-}"
		local port="${2:-}"

		if [[ -z "$host" || -z "$port" ]]; then
			_print_error "usage: tunnel <host> <port>"

			return 1
		fi

		_print_info "starting tunnel :$port to $host:$port..."

		# Run in foreground without -f. Use LocalCommand to format the success message after connecting.
		if ssh -N -o ExitOnForwardFailure=yes -o PermitLocalCommand=yes -o LocalCommand="printf '\033[32m::\033[0m tunnel opened on port $port\n'" -L "$port:localhost:$port" "$host"; then
			_print_success "tunnel closed cleanly"
		else
			_print_error "failed to open tunnel or closed with error"

			return 1
		fi
	)
}

# unpack an archive to a target directory automatically
function unpack() {
	(
		set -euo pipefail

		local file="${1:-}"
		local dir="${2:-.}"

		if [[ -z "$file" ]]; then
			_print_error "usage: unpack <archive> [target_dir]"

			return 1
		fi

		if [[ ! -f "$file" ]]; then
			_print_error "file '$file' not found"

			return 1
		fi

		mkdir -p "$dir"

		_print_info "unpacking $file to $dir"

		local base_file=$(basename "$file")

		case "${file,,}" in
			*.tar.*|*.tgz|*.tbz2|*.txz|*.tar)
				tar -xf "$file" -C "$dir"
				;;
			*.zip)
				unzip -q "$file" -d "$dir"
				;;
			*.gz)
				gzip -dkc "$file" > "$dir/${base_file%.gz}"
				;;
			*.bz2)
				bzip2 -dkc "$file" > "$dir/${base_file%.bz2}"
				;;
			*.xz)
				xz -dkc "$file" > "$dir/${base_file%.xz}"
				;;
			*.zst)
				zstd -dqc "$file" -o "$dir/${base_file%.zst}"
				;;
			*)
				_print_error "unsupported or unrecognized archive format '$file'"

				return 1
				;;
		esac

		_print_success "unpacked"
	)
}

# pack files into an archive or compressed file based on the target's extension
function pack() {
	(
		set -euo pipefail

		local target="${1:-}"

		local files=()
		if (( $# > 1 )); then
			files=("${@:2}")
		fi

		if [[ -z "$target" ]]; then
			_print_error "usage: pack <target> [files...]"

			return 1
		fi

		# no inputs given: pack the current directory
		if (( ${#files[@]} == 0 )); then
			files=(.)
		fi

		local f
		for f in "${files[@]}"; do
			if [[ ! -e "$f" ]]; then
				_print_error "file '$f' not found"

				return 1
			fi
		done

		# resolve the format first so multi-part suffixes (.tar.gz) win over plain ones (.gz)
		local kind
		case "${target,,}" in
			*.tar.gz|*.tgz)   kind="tar.gz" ;;
			*.tar.bz2|*.tbz2) kind="tar.bz2" ;;
			*.tar.xz|*.txz)   kind="tar.xz" ;;
			*.tar.zst|*.tzst) kind="tar.zst" ;;
			*.tar)            kind="tar" ;;
			*.zip)            kind="zip" ;;
			*.gz)             kind="gz" ;;
			*.bz2)            kind="bz2" ;;
			*.xz)             kind="xz" ;;
			*.zst)            kind="zst" ;;
			*)
				_print_error "unsupported or unrecognized archive format '$target'"

				return 1
				;;
		esac

		# single-stream compressors hold exactly one regular file
		case "$kind" in
			gz|bz2|xz|zst)
				if (( ${#files[@]} != 1 )) || [[ ! -f "${files[0]}" ]]; then
					_print_error "'$target' compresses a single file; pass exactly one regular file"

					return 1
				fi
				;;
		esac

		mkdir -p -- "$(dirname -- "$target")"

		_print_info "packing ${files[*]} into $target"

		case "$kind" in
			tar)     tar -cf "$target" -- "${files[@]}" ;;
			tar.gz)  tar -czf "$target" -- "${files[@]}" ;;
			tar.bz2) tar -cjf "$target" -- "${files[@]}" ;;
			tar.xz)  tar -cJf "$target" -- "${files[@]}" ;;
			tar.zst) tar --zstd -cf "$target" -- "${files[@]}" ;;
			zip)     zip -rq "$target" "${files[@]}" ;;
			gz)      gzip -c "${files[0]}" > "$target" ;;
			bz2)     bzip2 -c "${files[0]}" > "$target" ;;
			xz)      xz -c "${files[0]}" > "$target" ;;
			zst)     zstd -qc "${files[0]}" -o "$target" ;;
		esac

		_print_success "packed"
	)
}

# search shell history (literal by default, -r for regex)
function hist() {
	local use_regex=false

	if [[ "${1:-}" == "-r" ]]; then
		use_regex=true

		shift
	fi

	if (( $# == 0 )); then
		_print_error "usage: hist [-r] <pattern>"

		return 1
	fi

	local pattern="$*"

	if [[ "$use_regex" == true ]]; then
		history | grep --color=auto -e "$pattern"
	else
		history | grep --color=auto -F -e "$pattern"
	fi
}

# download and run vencord installer
function vencord() {
	sh -c "$(curl -sS https://vencord.dev/install.sh)"
}

# trigger terminal bell
function beep() {
	printf '\a'
}

# fix directory and file permissions for web hosting
function perms() {
	(
		set -euo pipefail

		if [[ $# -eq 0 ]]; then
			_print_error "usage: perms <directory>"

			return 1
		fi

		local target
		target=$(realpath "$1")

		if [[ ! -d "$target" ]]; then
			_print_error "'$target' is not a directory"

			return 1
		fi

		_print_info "fixing permissions in $target"

		_print_sub "directories -> 755"
		find "$target" -type d -exec chmod 755 {} +

		_print_sub "files -> 644"
		find "$target" -type f -exec chmod 644 {} +

		_print_success "permissions updated"
	)
}

# safer rm that confirms folder deletes
function rm() {
	(
		local arg path reply
		local parsing_opts=true
		local recursive=false

		for arg in "$@"; do
			if [[ "$parsing_opts" == true ]]; then
				case "$arg" in
					--)
						parsing_opts=false
						;;
					--recursive)
						recursive=true
						;;
					-[!-]*)
						if [[ "$arg" == *[rR]* ]]; then
							recursive=true
						fi
						;;
				esac
			fi
		done

		parsing_opts=true

		for arg in "$@"; do
			if [[ "$parsing_opts" == true ]]; then
				case "$arg" in
					--)
						parsing_opts=false

						continue
						;;
					-*)
						continue
						;;
				esac
			fi

			if [[ -d "$arg" && ! -L "$arg" ]]; then
				path="$(cd -- "$arg" && pwd -P)" || return 1

				if [[ "$path" == "/" ]]; then
					_print_error "refusing to remove /"

					return 1
				fi

				if [[ "$recursive" != true ]]; then
					_print_error "directory '$path' requires -r"

					return 1
				fi

				local depth=0
				local probe="$path"

				while [[ "$probe" != "/" ]]; do
					probe="${probe%/*}"

					if [[ -z "$probe" ]]; then
						probe="/"
					fi

					((depth += 1))
				done

				if (( depth <= 2 )); then
					printf "\033[31m!?\033[0m remove \033[31m%s\033[0m? [y/N] " "$path"
					read -r reply
				else
					_read_line "remove $(printf '\033[36m%s\033[0m' "$path")? [y/N] " reply
				fi

				case "$reply" in
					[yY]) ;;
					*)
						_print_error "rm aborted"

						return 1
						;;
				esac
			fi
		done

		command rm "$@"
	)
}

# update env
function envup() {
	(
		set -euo pipefail

		local env_dir=""

		if [[ -n "${USERPROFILE:-}" && -d "$USERPROFILE/env" ]]; then
			env_dir="$USERPROFILE/env"
		elif [[ -d "$HOME/env" ]]; then
			env_dir="$HOME/env"
		else
			_print_error "env directory not found"

			return 1
		fi

		_print_info "updating env in $env_dir"

		cd "$env_dir"

		sudo --preserve-env=SSH_CLIENT,SSH_AUTH_SOCK,USERPROFILE,HOME bash setup.sh
	)
}

##
# Shell settings
##

# Only show directories for certain completions
complete -o filenames -o dirnames -F _directory_complete cd

complete -o filenames -o dirnames -F _directory_complete pull push tag dtag rtag tags git_ssh origin trash goup gover perms

# Preserve Bash's other completion types when no path matches.
complete -o filenames -o bashdefault -o default -F _path_complete -D

# filtered extension completions
filter_completions "sqlite3" "db"

# various aliases
alias grep='grep --color=auto'
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -la'
alias tidy='go mod tidy'
alias mkdir='mkdir -p'
alias ports='ss -tulpn'
alias ..='cd ..'
alias ...='cd ../..'
alias home='cd ~'
alias cls='clear'
alias prun='php artisan serve --port=80'

# password-only ssh, ignoring ssh config
alias sshpw='ssh -F /dev/null -o BatchMode=no -o PubkeyAuthentication=no -o PreferredAuthentications=password -o NumberOfPasswordPrompts=3'

alias bench='builder bench'
alias test='builder test'
alias run='builder run'
alias build='builder build'
alias sign='builder sign'
alias verify='builder verify'

if type -P time >/dev/null 2>&1; then
	alias t='command time'
fi

# auto-correct cd typos
shopt -s cdspell
# auto-correct completion typos
shopt -s dirspell
# update window size
shopt -s checkwinsize
# enable ** globbing
shopt -s globstar
# extended pattern matching
shopt -s extglob
# append to history
shopt -s histappend
# multi-line commands in one history entry
shopt -s cmdhist
# match globs case-insensitively
shopt -s nocaseglob
# warn about running jobs before exit
shopt -s checkjobs

# better history
export HISTCONTROL=ignoreboth
export HISTIGNORE="ssh-add *:password *:secret *"
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTTIMEFORMAT="%F %T "

# so ssh/etc properly detect the terminal
export TERM=xterm-256color

# default editor, nano ontop
export EDITOR=nano

# ignore .cmd extension for complete
export FIGNORE=".cmd:.exe"

# write history immediately
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# wtf completions
if command -v wtf >/dev/null 2>&1; then
	eval "$(wtf --completion bash)"
fi

##
# CGo settings
##

export CGO_ENABLED=1

# skip the rest, if connected via ssh
if [[ -n "$SSH_CLIENT" ]]; then
	return
fi

##
# SSH Agent
##

# WSL only key sync (also sets $USERPROFILE in WSL)
if [[ -n "$WSL_DISTRO_NAME" || -n "$WSL_INTEROP" ]]; then
	if [[ -z "${USERPROFILE:-}" ]]; then
		WIN_PROFILE_WIN=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')

		if [[ -n "$WIN_PROFILE_WIN" ]]; then
			export USERPROFILE=$(wslpath "$WIN_PROFILE_WIN")
		fi
	fi

	if [[ -n "${USERPROFILE:-}" ]]; then
		WIN_KEY="$USERPROFILE/.ssh/keys/github"
		WSL_KEY_DIR="$HOME/.ssh/keys"
		WSL_KEY="$WSL_KEY_DIR/github"

		if [[ -f "$WIN_KEY" && ! -f "$WSL_KEY" ]]; then
			mkdir -p "$WSL_KEY_DIR"

			cp "$WIN_KEY" "$WSL_KEY"

			chmod 700 "$HOME/.ssh" "$WSL_KEY_DIR"
			chmod 600 "$WSL_KEY"
		fi
	fi
fi

# ensure ssh-agent is running
SSH_AGENT_FILE="$HOME/.ssh/.agent-env"

if [[ -r "$SSH_AGENT_FILE" ]]; then
	source "$SSH_AGENT_FILE" >/dev/null 2>&1
fi

if ! ssh-add -l >/dev/null 2>&1; then
	ssh-agent -s > "$SSH_AGENT_FILE"
	source "$SSH_AGENT_FILE" >/dev/null 2>&1

	chmod 600 "$SSH_AGENT_FILE"
fi

# ensure github ssh key is loaded
if [ -f "$HOME/.ssh/keys/github" ]; then
	ssh-add "$HOME/.ssh/keys/github" > /dev/null 2>&1
fi

##
# Git settings
##

if ! git config --global --get-all include.path | grep -Fxq "~/.config/.gitconfig_env"; then
	git config --global --add include.path "~/.config/.gitconfig_env"
fi

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

PROMPT_COMMAND="__reset_exit_code; ${PROMPT_COMMAND:-}"
