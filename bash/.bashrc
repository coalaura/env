#!/bin/bash
# ~/.bashrc
# by coalaura

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

##
# Helper Functions
##

# Starts a timer
function _start_timer() {
    date +%s%3N 2>/dev/null || echo 0
}

# Stops and prints a started timer
function _end_timer() {
    local start_time="$1"
    local action_name="${2:-built}"
    local end_time=$(_start_timer)

    if [[ "$start_time" != "0" && "$end_time" != "0" ]]; then
        local elapsed=$((end_time - start_time))

        if [[ $elapsed -lt 1000 ]]; then
            printf "\033[90m- %s in %dms\033[0m\n" "$action_name" "$elapsed"
        else
            local sec=$(awk "BEGIN {printf \"%.2f\", $elapsed/1000}")

            printf "\033[90m- %s in %ss\033[0m\n" "$action_name" "$sec"
        fi
    else
        printf "\033[90m- %s\033[0m\n" "$action_name"
    fi
}

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

# Run go generate for a project
function _go_generate() {
	local target="${1:-.}"

	printf "\033[37m[go] generating %s\033[0m\n" "$target"

	local t0=$(_start_timer)

	if ! go -C "$target" generate ./...; then
		return 1
	fi

	_end_timer "$t0" "generated"
}

# Setup Go build environment and parse custom flags
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

    GO_BUILD_FLAGS=("-trimpath" "-pgo=auto" "-buildvcs=false")
    GO_LDFLAGS="-s -w"

    if [[ "$is_pure" == "true" ]]; then
        export CGO_ENABLED=0

        _add_go_tags "netgo,osusergo"

        unset CC CXX CGO_CFLAGS CGO_CXXFLAGS CGO_LDFLAGS
    else
        export CGO_ENABLED=1
    fi

    if (( ${#merged_tags[@]} > 0 )); then
        GO_BUILD_FLAGS+=("-tags" "$(IFS=,; echo "${merged_tags[*]}")")
    fi

    if [[ "$is_compat" == "true" ]]; then
        export GOAMD64=v1
    else
        export GOAMD64=v3
    fi

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
            GO_LDFLAGS="$GO_LDFLAGS -linkmode external -extldflags '-static'"
        fi

        local is_cross=false

        if [[ "$target_os" != "linux" ]] || [[ "$target_arch" != "$host_arch" ]]; then
            is_cross=true
        fi

        if [[ "$is_cross" == "true" && -n "$zig_target" ]]; then
            export CC="zig cc -target $zig_target"
            export CXX="zig c++ -target $zig_target"
        else
            export CC="zig cc"
            export CXX="zig c++"
        fi

        local opt_level="-O3"

        if [[ "$is_min" == "true" ]]; then
            opt_level="-Os"
        fi

        local cflags="-g0 $opt_level -ffunction-sections -fdata-sections"

        if [[ "$target_arch" == "amd64" ]]; then
            if [[ "$is_compat" == "true" ]]; then
                cflags="$cflags -march=x86_64"
            else
                cflags="$cflags -march=x86_64_v3"
            fi
        fi

        export CGO_CFLAGS="$cflags"
        export CGO_CXXFLAGS="$cflags"
        export CGO_LDFLAGS="-Wl,--gc-sections"
    fi
}

# handle .command shorthand for local executables
function command_not_found_handle() {
    local cmd="$1"

    shift

    if [[ "$cmd" =~ ^\.([a-zA-Z0-9_]+)$ ]]; then
        local name="${BASH_REMATCH[1]}"

        # .sh files first (run with bash)
        if [[ -f "./${name}.sh" ]]; then
            printf "\033[37mrunning ./%s.sh\033[0m\n" "$name"

			bash "./${name}.sh" "$@"

            return $?
        fi

        # executable without extension
        if [[ -f "./${name}" && -x "./${name}" ]]; then
            printf "\033[37mrunning ./%s\033[0m\n" "$name"

		    "./${name}" "$@"

		    return $?
        fi

        printf "\033[33merror: no executable found for .%s\033[0m\n" "$name"

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
# Commands
##

# git root detector
function git_root() {
	local path="${1:-.}"

	git -C "$path" rev-parse --show-toplevel 2>/dev/null || echo "$path"
}

# perform system maintenance and updates
function update() {
	(
		set -euo pipefail

		function print_time() {
			echo "[$(date '+%H:%M:%S')] - $1"
		}

		function get_space() {
			df --output=used -B1 / | tail -n1 | xargs
		}

		read -r used_before < <(get_space)

		##
		# arch (pacman, paru, yay)
		##
		if command -v pacman &> /dev/null; then
			if command -v paru &> /dev/null; then
				print_time "paru -syu"
				paru -Syu --noconfirm > /dev/null
			elif command -v yay &> /dev/null; then
				print_time "yay -syu"
				yay -Syu --noconfirm > /dev/null
			else
				print_time "pacman -syu"
				sudo pacman -Syu --noconfirm > /dev/null
			fi

			print_time "pacman -sc"

			if command -v paccache &> /dev/null; then
				sudo paccache -rk2 -ruk0 >/dev/null 2>&1 || true
			else
				sudo pacman -Sc --noconfirm > /dev/null
			fi

			print_time "pacman -rns (orphans)"

			readarray -t orphans < <(pacman -Qtdq 2>/dev/null || true)
			if (( ${#orphans[@]} )); then
				sudo pacman -Rns --noconfirm "${orphans[@]}" > /dev/null 2>&1 || true
			fi
		fi

		##
		# debian (apt)
		##
		if command -v apt-get &> /dev/null; then
			print_time "apt update"
			sudo apt-get update -qq

			print_time "apt full-upgrade"
			sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y -qq > /dev/null

			print_time "apt autoremove"
			sudo env DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y -qq > /dev/null

			print_time "apt clean"
			sudo apt-get clean -qq > /dev/null
		fi

		##
		# other (flatpak, snap)
		##
		if command -v flatpak &> /dev/null; then
			print_time "flatpak update"
			flatpak update -y > /dev/null 2>&1 || true

			print_time "flatpak uninstall unused"
			flatpak uninstall --unused -y > /dev/null 2>&1 || true
		fi

		if command -v snap &> /dev/null; then
			print_time "snap refresh"
			sudo snap refresh > /dev/null 2>&1 || true
		fi

		##
		# docker
		##
		if command -v docker &> /dev/null; then
			print_time "docker system prune"
			sudo docker system prune --all --force --volumes > /dev/null 2>&1 || true

			for cid in $(sudo docker ps -q 2>/dev/null || true); do
				print_time "docker clean container $cid"
				sudo docker exec "$cid" sh -c "rm -rf /tmp/* /tmp/.[!.]* /tmp/..?* /var/tmp/* /var/tmp/.[!.]* /var/tmp/..?*" > /dev/null 2>&1 || true
			done
		fi

		##
		# logs & temp
		##
		if command -v journalctl &> /dev/null; then
			print_time "journalctl vacuum"
			sudo journalctl --vacuum-time=14d >/dev/null 2>&1 || true
		fi

		print_time "clean old logs"
		sudo find /var/log -type f \( -name "*.log" -o -name "*.gz" \) -mtime +14 -delete > /dev/null 2>&1 || true

		print_time "clean old /tmp"
		sudo find /tmp -type f -atime +7 -delete > /dev/null 2>&1 || true

		print_time "clean old /var/tmp"
		sudo find /var/tmp -type f -atime +7 -delete > /dev/null 2>&1 || true

		##
		# summary
		##
		read -r used_after < <(get_space)

		freed=$((used_before - used_after))

		if (( freed > 0 )); then
			freed_human=$(numfmt --to=iec "$freed" 2>/dev/null || echo "${freed}B")
			print_time "completed (freed $freed_human)"
		elif (( freed < 0 )); then
			used_human=$(numfmt --to=iec "$(( -freed ))" 2>/dev/null || echo "$(( -freed ))B")
			print_time "completed (used additional $used_human space)"
		else
			print_time "completed"
		fi
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

# delete and push-delete a git tag
function dtag() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local -a tags=()

		readarray -t tags < <(git -C "$target" tag --sort=-creatordate | head -n 5)

		if (( ${#tags[@]} == 0 )); then
			printf "\033[33merror: no tags found\033[0m\n"

			return 1
		fi

		printf "\x1b[90mlatest:\033[0m\n"

		local tag_name

		for tag_name in "${tags[@]}"; do
			printf "\x1b[90m- %s\033[0m\n" "$tag_name"
		done

		printf "\n"

		read -rp "delete tag: " tag_name

		tag_name="$(echo "$tag_name" | xargs)"

		if [[ -z "$tag_name" ]]; then
			printf "\033[33merror: tag name is required\033[0m\n"

			return 1
		fi

		printf "\033[37mdeleting %s from %s\033[0m\n" "$tag_name" "$target"

		if ! git -C "$target" push origin ":refs/tags/$tag_name"; then
			printf "\033[33merror: failed to delete remote tag\033[0m\n"

			return 1
		fi

		if ! git -C "$target" tag -d "$tag_name"; then
			printf "\033[33merror: failed to delete local tag\033[0m\n"

			return 1
		fi

		printf "\033[32msuccess: deleted and pushed %s\033[0m\n" "$tag_name"
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

# reset and cleans git repo
function trash() {
	(
		set -euo pipefail

		local target=$(git_root "${1:-.}")

		if [ ! -d "$target/.git" ]; then
			printf "\033[33merror: %s is not a git repository\033[0m\n" "$target"

			return 1
		fi

		local confirm

		read -rp "trash everything in $(basename "$target")? [y/N] " confirm

		if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
			printf "\033[33maborted\033[0m\n"

			return 1
		fi

		printf "\033[37maborting pending operations...\033[0m\n"

		git -C "$target" rebase --abort 2>/dev/null || true
		git -C "$target" merge --abort 2>/dev/null || true
		git -C "$target" cherry-pick --abort 2>/dev/null || true
		git -C "$target" bisect reset 2>/dev/null || true

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

			_apply_go_env "linux" "amd64" "${extra_args[@]}"
			_go_generate "$target"

			if [[ -n "$focus" ]]; then
				printf "\033[37m[go] profiling %s (focus: %s, mode: %s)\033[0m\n" "$target" "$focus" "$GO_MODE_STR"

				go build -gcflags="-m -m" ./... 2>&1 | grep -i "$focus" > .profile/escape_analysis.txt || true
				go build -gcflags="-d=ssa/check_bce/debug=1" ./... 2>&1 | grep -i "$focus" > .profile/bce.txt || true
			else
				printf "\033[37m[go] profiling %s (mode: %s)\033[0m\n" "$target" "$GO_MODE_STR"

				go build -gcflags="-m" ./... > .profile/escape_analysis.txt 2>&1 || true
				go build -gcflags="-d=ssa/check_bce/debug=1" ./... > .profile/bce.txt 2>&1 || true
			fi

			go test -run=^$ -bench=. -benchmem \
				-cpuprofile=.profile/cpu.prof \
				-memprofile=.profile/mem.prof \
				-mutexprofile=.profile/mutex.prof \
				-blockprofile=.profile/block.prof \
				-trace=.profile/trace.out \
				"${GO_EXTRA_ARGS[@]}" ./... > .profile/bench.txt 2>&1 || true

			printf "\033[32msuccess: profile complete\033[0m\n"
			printf "\033[37m  escape/inline: .profile/escape_analysis.txt\033[0m\n"
			printf "\033[37m  bce misses:    .profile/bce.txt\033[0m\n"
			printf "\033[37m  benchmarks:    .profile/bench.txt\033[0m\n"
			printf "\033[37m  cpu profile:   go tool pprof -http=:8080 .profile/cpu.prof\033[0m\n"
			printf "\033[37m  mem profile:   go tool pprof -http=:8081 .profile/mem.prof\033[0m\n"
			printf "\033[37m  mutex blocks:  go tool pprof -http=:8082 .profile/mutex.prof\033[0m\n"
			printf "\033[37m  trace ui:      go tool trace .profile/trace.out\033[0m\n"

			return
		fi

		printf "\033[33merror: %s is not a recognized profile project\033[0m\n" "$target"
	)
)

# benchmark a project
function bench() (
	(
		set -euo pipefail

		local target="$(realpath ".")"
		local -a extra_args=("$@")

		# handle bench script
		if [[ -f "$target/bench.sh" ]]; then
			printf "\033[37m[bench.sh] benchmarking %s\033[0m\n" "$target"

			chmod +x ./bench.sh 2>/dev/null

			./bench.sh "${extra_args[@]}"

			return
		fi

		# handle go project
		if [[ -f "$target/go.mod" ]]; then
			_apply_go_env "linux" "amd64" "${extra_args[@]}"
			_go_generate "$target"

			printf "\033[37m[go] benchmarking %s (mode: %s)\033[0m\n" "$target" "$GO_MODE_STR"

			go test -run=^$ -bench=. -benchmem "${GO_EXTRA_ARGS[@]}" ./...

			return
		fi

		# handle node project
		if [[ -f "$target/package.json" ]]; then
			local script=""

			while IFS= read -r line; do
				case "$line" in
					*\"bench\"*:*)     script="${script:-bench}" ;;
					*\"benchmark\"*:*) script="${script:-benchmark}" ;;
				esac
			done < "$target/package.json"

			if [[ -n "$script" ]]; then
				printf "\033[37m[bun/%s] benchmarking %s\033[0m\n" "$script" "$target"

				bun run "$script" "${extra_args[@]}"

				return
			fi

			# fallback standalone bench files
			for file in "bench.js" "bench.ts" "benchmark.js" "benchmark.ts"; do
				if [[ -f "$target/$file" ]]; then
					printf "\033[37m[bun/%s] benchmarking %s\033[0m\n" "$file" "$target"

					bun "$file" "${extra_args[@]}"

					return
				fi
			done
		fi

		printf "\033[33merror: %s is not a recognized benchmark project\033[0m\n" "$target"
	)
)

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
			_apply_go_env "linux" "amd64" "${extra_args[@]}"
			_go_generate "$target"

			printf "\033[37m[go] testing %s (mode: %s)\033[0m\n" "$target" "$GO_MODE_STR"

			go test -v "${GO_EXTRA_ARGS[@]}" ./...

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
			local main_dir=$(_find_go_main_dir "$target")

			_apply_go_env "linux" "amd64" "${extra_args[@]}"
			_go_generate "$target"

			printf "\033[37m[go] running %s (mode: %s)\033[0m\n" "$main_dir" "$GO_MODE_STR"

			go run "${GO_EXTRA_ARGS[@]}" "$main_dir"

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
		local host_arch="$(go env GOHOSTARCH 2>/dev/null || uname -m)"

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
			local main_dir=$(_find_go_main_dir "$target")
			local base="$(basename "$target")"

			base="${base//[[:space:]]/}"

			if [[ "$target_os" == "windows" ]]; then
				base="$base.exe"
			fi

			_apply_go_env "$target_os" "$target_arch" "${extra_args[@]}"
			_go_generate "$target"

			printf "\033[37m[go/%s/%s] building %s (mode: %s)\033[0m\n" "$target_os" "$base" "$main_dir" "$GO_MODE_STR"

			local t0=$(_start_timer)

			go build "${GO_BUILD_FLAGS[@]}" -ldflags "$GO_LDFLAGS" "${GO_EXTRA_ARGS[@]}" -o "$base" "$main_dir"

			local exit_code=$?

			if [[ $exit_code -ne 0 ]]; then
				return $exit_code
			fi

			_end_timer "$t0" "built"

			if [[ "$GO_MINIFY" == "true" ]]; then
				if command -v upx &> /dev/null; then
					printf "\033[37m[upx] compressing %s\033[0m\n" "$base"

					local t1=$(_start_timer)

					upx --best --lzma "$base" > /dev/null

					_end_timer "$t1" "compressed"
				else
					printf "\033[33mwarning: upx not found, skipping compression\033[0m\n"
				fi
			fi

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

			local t0=$(_start_timer)

			bun run "$script" "${extra_args[@]}"

			local exit_code=$?

			if [[ $exit_code -ne 0 ]]; then
				return $exit_code
			fi

			_end_timer "$t0" "built"

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

# auto-fix/lint a project
function fix() (
	(
		set -euo pipefail

		local target="$(realpath ".")"

		local target_type="${1:-}"
		target_type="${target_type,,}"

		if [[ -z "$target_type" ]]; then
			if [[ -f "$target/go.mod" ]]; then
				target_type="go"
			elif [[ -f "$target/package.json" ]]; then
				target_type="js"
			fi
		fi

		case "$target_type" in
			go)
				printf "\033[37m[go] fixing %s\033[0m\n" "$target"

				go fix ./...
				go fmt ./...
				;;
			js)
				printf "\033[37m[biome] fixing %s\033[0m\n" "$target"

				biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path="$HOME/biome.json"
				;;
			*)
				printf "\033[33merror: unknown or undetected project type to fix\033[0m\n"

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
			printf "\033[33merror: %s is not a go project\033[0m\n" "$target"

			return 1
		fi

		local gv=$(go version | awk '{print $3}' | sed 's/^go//')

		go -C "$target" mod edit -go "$gv"

		printf "\033[32msuccess: set go version to %s\033[0m\n" "$gv"

		go -C "$target" get -u ./...

		go -C "$target" mod tidy

		printf "\033[32msuccess: updated packages\033[0m\n"
	)
}

# update github actions in workflows
ghup() (
	set -euo pipefail

	local target_dir="${1:-.}"
	target_dir="$(realpath "$target_dir")"

	local wf_dir="$target_dir/.github/workflows"

	if [[ ! -d "$wf_dir" ]]; then
		printf "\033[33merror: no workflows directory found at %s\033[0m\n" "$wf_dir"

		return 1
	fi

	local total=0
	local count=0

	shopt -s nullglob

	for pt in "$wf_dir"/*.yml "$wf_dir"/*.yaml; do
		if [[ -f "$pt" ]]; then
			continue
		fi

		((total += 1))

		local content="$(cat "$pt")"

		local new_content="$content"

		bump() {
			local action="$1"
			local old_majors="$2"
			local new_major="$3"

			perl -0pe "s{(\Q$action\E\@v)[$old_majors](?![.\d])}{\${1}$new_major}g"
		}

		new_content="$(printf '%s' "$new_content" | bump "actions/checkout" "1-5" "6")"
		new_content="$(printf '%s' "$new_content" | bump "actions/setup-go" "1-5" "6")"
		new_content="$(printf '%s' "$new_content" | bump "actions/cache" "1-4" "5")"
		new_content="$(printf '%s' "$new_content" | bump "actions/cache/restore" "1-4" "5")"
		new_content="$(printf '%s' "$new_content" | bump "actions/cache/save" "1-4" "5")"
		new_content="$(printf '%s' "$new_content" | bump "oven-sh/setup-bun" "1" "2")"
		new_content="$(printf '%s' "$new_content" | bump "biomejs/setup-biome" "1" "2")"
		new_content="$(printf '%s' "$new_content" | bump "actions/github-script" "1-6" "7")"
		new_content="$(printf '%s' "$new_content" | bump "actions/upload-artifact" "4-5" "6")"
		new_content="$(printf '%s' "$new_content" | bump "actions/download-artifact" "4-7" "8")"

		if ! grep -Eq '^[[:space:]-]*always-auth[[:space:]]*:' <<< "$new_content"; then
			new_content="$(printf '%s' "$new_content" | bump "actions/setup-node" "1-5" "6")"
		fi

		if [[ "$new_content" != "$content" ]]; then
			printf '%s' "$new_content" > "$pt"
			printf "\033[37mupdated %s\033[0m\n" "$(basename "$pt")"

			((count += 1))
		fi
	done

	if (( total == 0 )); then
		printf "\033[37mno workflows found\033[0m\n"
	elif (( count == 0 )); then
		printf "\033[37mall actions are up to date (%d files checked)\033[0m\n" "$total"
	else
		printf "\033[32msuccess: updated actions in %d/%d workflow(s)\033[0m\n" "$count" "$total"
	fi
)

# create an ssh tunnel for a specific port
function tunnel() {
	(
		set -euo pipefail

		local host="${1:-}"
		local port="${2:-}"

		if [[ -z "$host" || -z "$port" ]]; then
			printf "\033[33merror: usage: tunnel <host> <port>\033[0m\n"

			return 1
		fi

		printf "\033[37mtunneling port %s to %s\033[0m\n" "$port" "$host"

		ssh -N -L "$port:localhost:$port" "$host"
	)
}

# unpack an archive to a target directory automatically
function unpack() {
	(
		set -euo pipefail

		local file="${1:-}"
		local dir="${2:-.}"

		if [[ -z "$file" ]]; then
			printf "\033[33merror: usage: unpack <archive> [target_dir]\033[0m\n"

			return 1
		fi

		if [[ ! -f "$file" ]]; then
			printf "\033[33merror: file '%s' not found\033[0m\n" "$file"

			return 1
		fi

		mkdir -p "$dir"

		printf "\033[37munpacking %s to %s\033[0m\n" "$file" "$dir"

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
				printf "\033[33merror: unsupported or unrecognized archive format '%s'\033[0m\n" "$file"

				return 1
				;;
		esac

		printf "\033[32msuccess: unpacked\033[0m\n"
	)
}

# pulls a docker compose container
function dockup() {
	docker compose down && docker compose pull && docker compose up -d
}

# download and run vencord installer
function vencord() {
	sh -c "$(curl -sS https://vencord.dev/install.sh)"
}

# trigger terminal bell
function beep() {
	printf '\a'
}

# safer rm that blocks absolute paths
function rm() {
	local arg

	for arg in "$@"; do
		case "$arg" in
			-*) ;;
			/*)
				printf "\033[33merror: absolute path in rm: %s\033[0m\n" "$arg"
				return 1
				;;
		esac
	done

	command rm "$@"
}

##
# Shell settings
##

# Only show directories for certain completions
complete -d cd

complete -o dirnames -A directory pull push git_ssh origin trash goup ghup
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

if type -P time >/dev/null 2>&1; then
	alias t='command time'
fi

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

# ignore .cmd extension for complete
export FIGNORE=".cmd:.exe"

##
# CGo settings
##

export CGO_ENABLED=1
export CC="zig cc"
export CXX="zig c++"

# skip the rest, if connected via ssh
[[ -n "$SSH_CLIENT" ]] && return

##
# SSH Agent
##

# ensure ssh-agent is running
SSH_AGENT_FILE="$HOME/.ssh/.agent-env"

if [[ -r "$SSH_AGENT_FILE" ]]; then
	source "$SSH_AGENT_FILE" >/dev/null 2>&1
fi

if ! ssh-add -l >/dev/null 2>&1; then
	ssh-agent -s > "$SSH_AGENT_FILE"
	source "$SSH_AGENT_FILE" >/dev/null 2>&1
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