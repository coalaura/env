local json = require("json")

local _M = {}

local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
local host = os.getenv("COMPUTERNAME") or ""

function _M.home()
    return home
end

function _M.hostname()
    return host
end

function _M.exists(pt)
    return os.isdir(pt) or os.isfile(pt)
end

function _M.read_file(pt)
    local file = io.open(pt, "rb")

    if not file then
        return nil
    end

    local content = file:read("*a")

    file:close()

    return content
end

function _M.write_file(pt, data)
    local file = io.open(pt, "w")

    if not file then
        return
    end

    file:write(data)
    file:close()
end

function _M.is_git(dir)
    local git_dir = path.join(dir, ".git")

    if not os.isdir(git_dir) then
        return false, string.format("%s is not a git repository", _M.clean_path(dir))
    end

    local handle = io.popen(string.format("git.exe -C %s status -s 2>&1", _M.escape_path(dir)))

    if not handle then
        return false, "failed to run git"
    end

    local out = handle:read("*a") or ""

    if not handle:close() then
        local msg = out:match("fatal: [^\r\n]+")

        return false, msg or "git error"
    end

    return true
end

function _M.is_go(dir)
    return os.isfile(path.join(dir, "go.mod"))
end

function _M.is_node(dir)
    return os.isfile(path.join(dir, "package.json"))
end

function _M.git_root(dir)
    local handle = io.popen(string.format("git.exe -C %s rev-parse --show-toplevel 2>nul", _M.escape_path(dir)))

    if not handle then
        return dir
    end

    local target = handle:read("*l")

    handle:close()

    if not target or target == "" then
        return dir
    end

    return target
end

function _M.git_remote(dir)
    local handle = io.popen(string.format("git.exe -C %s remote get-url origin 2>nul", _M.escape_path(dir)))

    if not handle then
        return false
    end

    local url = handle:read("*l")

    handle:close()

    return url ~= "" and url or false
end

function _M.clean_path(pt)
    pt = path.normalise(pt)

    return rl.collapsetilde(pt, true)
end

function _M.trim(str)
    return (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function _M.escape_path(pt, escapeQuotes)
    pt = path.normalise(pt)

    pt = pt:gsub("[/\\]+$", "")
    pt = pt:gsub("\"", "\"\"")

    if escapeQuotes then
        return string.format("^\"%s^\"", pt)
    end

    return string.format("\"%s\"", pt)
end

function _M.escape_input(str)
    if not str then
        return ""
    end

    str = str:gsub('"', '""')

    return str
end

function _M.basename(pt)
    pt = path.normalise(pt)

    pt = pt:gsub("[/\\]+$", "")
    pt = pt:gsub("[^%w/\\-]+", "")

    local base = path.getbasename(pt)

    base = base:gsub("[ \t\\/]", "")

    if base == "" then
        return false
    end

    return base
end

function _M.background(commands)
    local sub = table.concat(commands, " && "):gsub("\"", "^\"")

    os.execute(string.format("start /b cmd /c \"%s\"", sub))
end

function _M.start_timer()
    return os.clock()
end

function _M.end_timer(start_time, action_name)
    action_name = action_name or "built"

    local elapsed = os.clock() - start_time

    if elapsed < 1.0 then
        _M.printf("\x1b[90m- %s in %dms", action_name, math.floor(elapsed * 1000))
    else
        _M.printf("\x1b[90m- %s in %.2fs", action_name, elapsed)
    end
end

function _M.command_ok(result)
	return result == true or result == 0
end

function _M.go_generate(dir, env)
    _M.printf("[go] generating %s", _M.clean_path(dir))

    local t0 = _M.start_timer()

    local cmd = string.format(
		"go -C %s generate ./...",
		_M.escape_path(dir)
	)

    local gen_result = os.execute(_M.command_with_env(
        cmd,
        env
    ))

    if not _M.command_ok(gen_result) then
        return false
    end

    _M.end_timer(t0, "generated")

    return true
end

local function escape_cmd_set_value(v)
    v = tostring(v)

    v = v:gsub("%^", "^^") -- caret first
    v = v:gsub("%%", "%%%%") -- prevent %VAR% expansion
    v = v:gsub('"', '^"') -- literal quote

    return v
end

function _M.command_with_env(command, env)
    local entries = {}

    if env then
        for key, value in pairs(env) do
            table.insert(entries, string.format(
                "set \"%s=%s\"",
                key,
                escape_cmd_set_value(value)
            ))
        end
    end

    table.insert(entries, command)

    return string.format("cmd /v:off /c \"%s\"", table.concat(entries, " && "))
end

-- Parse target directory and extra arguments separated by --
-- Returns: target_dir (string), extra_args (table)
function _M.parse_target_and_args(args)
    if not args or args == "" then
        return os.getcwd(), {}
    end

    -- Match everything before and after --
    local target_part, rest = args:match("^(.-)%s*%-%-%s*(.*)$")

    if not target_part then
        -- No -- separator found
        target_part = args

        rest = ""
    end

    local target = target_part:match("^%s*(.-)%s*$")

    if target == "" then
        target = os.getcwd()
    end

    -- Parse remaining arguments into table
    local extra_args = {}

    if rest and rest ~= "" then
        for arg in rest:gmatch("%S+") do
            table.insert(extra_args, arg)
        end
    end

    return target, extra_args
end

function _M.format_extra_args(args)
    if not args or #args == 0 then
        return ""
    end

    if type(args) == "string" then
        return args
    end

    local escaped = {}

    for _, arg in ipairs(args) do
        table.insert(escaped, _M.escape_input(arg))
    end

    return " " .. table.concat(escaped, " ")
end

function _M.parse_target_os(args)
    args = _M.trim(args or "")

    local words = {}

    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end

    local target = "windows"
    local remaining = {}

    for _, word in ipairs(words) do
        local lower = word:lower()

        if lower == "win" or lower == "windows" then
            target = "windows"
        elseif lower == "lin" or lower == "linux" then
            target = "linux"
        elseif lower == "dar" or lower == "darwin" then
            target = "darwin"
        else
            table.insert(remaining, word)
        end
    end

    local rest = table.concat(remaining, " ")

    if rest == "" then
        rest = false
    end

    return target, rest
end

function _M.prepare_go_env(target_os, target_arch, extra_args_str)
    local is_pure = false
    local is_compat = false
    local is_min = false

    extra_args_str = extra_args_str or ""

    if extra_args_str:match("%-%-pure") then
        is_pure = true

        extra_args_str = extra_args_str:gsub("%s*%-%-pure%s*", " ")
    end

    if extra_args_str:match("%-%-compat") then
        is_compat = true

        extra_args_str = extra_args_str:gsub("%s*%-%-compat%s*", " ")
    end

    if extra_args_str:match("%-%-min") then
        is_min = true

        extra_args_str = extra_args_str:gsub("%s*%-%-min%s*", " ")
    end

    local words = {}

    for word in extra_args_str:gmatch("%S+") do
        table.insert(words, word)
    end

    local passthrough = {}
    local merged_tags = {}
    local seen_tags = {}

    local function add_tags(tag_str)
        for tag in tostring(tag_str or ""):gmatch("[^,%s]+") do
            if not seen_tags[tag] then
                seen_tags[tag] = true

                table.insert(merged_tags, tag)
            end
        end
    end

    local i = 1

    while i <= #words do
        local word = words[i]

        if word == "-tags" or word == "--tags" then
            if i < #words then
                add_tags(words[i + 1])

                i = i + 2
            else
                i = i + 1
            end
        else
            local inline_tags = word:match("^%-%-?tags=(.+)$")

            if inline_tags then
                add_tags(inline_tags)
            else
                table.insert(passthrough, word)
            end

            i = i + 1
        end
    end

    local env = {
        GOOS = target_os,
        GOARCH = target_arch,
    }

    local build_flags = "-trimpath -pgo=auto -buildvcs=false"
    local ldflags = "-s -w"

    if is_pure then
        add_tags("netgo,osusergo")

        env.CGO_ENABLED = "0"
        env.CC = ""
        env.CXX = ""
    else
        env.CGO_ENABLED = "1"
    end

    if #merged_tags > 0 then
        build_flags = build_flags .. " -tags " .. table.concat(merged_tags, ",")
    end

    if is_compat then
        env.GOAMD64 = "v1"
    else
        env.GOAMD64 = "v3"
    end

    local mode_str = (is_pure and "pure" or "cgo") .. (is_compat and ",compat" or ",opt") .. (is_min and ",min" or "")

    if env.CGO_ENABLED == "1" then
        if target_os == "linux" or target_os == "windows" then
            ldflags = ldflags .. " -linkmode external -extldflags=-static"
        end

        local zig_targets = {
            ["linux"] = "x86_64-linux-musl",
            ["windows"] = "x86_64-windows-gnu",
            ["darwin"] = "x86_64-macos-none"
        }

        local zig_target = zig_targets[target_os]

        if zig_target then
            env.CC = "zig cc -target " .. zig_target
            env.CXX = "zig c++ -target " .. zig_target
        else
            env.CC = "zig cc"
            env.CXX = "zig c++"
        end

        local opt_level = is_min and "-Os" or "-O3"

        local cflags = "-g0 " .. opt_level .. " -ffunction-sections -fdata-sections"

        if target_arch == "amd64" then
            if is_compat then
                cflags = cflags .. " -march=x86_64"
            else
                cflags = cflags .. " -march=x86_64_v3"
            end
        end

        env.CGO_CFLAGS = cflags
        env.CGO_CXXFLAGS = cflags
        env.CGO_LDFLAGS = "-Wl,--gc-sections"
    end

    return {
        env = env,
        build_flags = build_flags,
        ldflags = ldflags,
        extra_args = _M.trim(table.concat(passthrough, " ")),
        mode = mode_str,
        is_min = is_min
    }
end

function _M.get_package_json_script(pt, allowed)
    local body = _M.read_file(pt)

    local data = body and json.decode(body)

    if not data then
        return false
    end

    local scripts = data.scripts

    if not scripts or type(scripts) ~= "table" then
        return false
    end

    for id, script in ipairs(allowed) do
        if scripts[script] then
            return script
        end
    end

    return false
end

function _M.get_first_existing_file(dir, allowed)
    for id, file in ipairs(allowed) do
        local pt = path.join(dir, file)

        if os.isfile(pt) then
            return file
        end
    end

    return false
end

function _M.find_go_main_dir(root)
    root = path.normalise(root)

    local handle = io.popen(string.format("dir /b \"%s\\*.go\" 2>nul", root))

    if handle then
        for file in handle:lines() do
            local content = _M.read_file(path.join(root, file)) or ""

            if content:match("package%s+main") and content:match("func%s+main%s*%(") then
                handle:close()

                return root
            end
        end

        handle:close()
    end

    local cmd = string.format("cd /d \"%s\" && go list -f \"{{.Name}}|{{.Dir}}\" ./... 2>nul", root)

    local list_handle = io.popen(cmd)

    if not list_handle then
        return root
    end

    local candidates = {}

    for line in list_handle:lines() do
        local pkg_name, pkg_dir = line:match("^([^|]+)|(.+)$")

        if pkg_name == "main" and pkg_dir then
            local dir_handle = io.popen(string.format("dir /b \"%s\\*.go\" 2>nul", pkg_dir))

            if dir_handle then
                for file in dir_handle:lines() do
                    local content = _M.read_file(path.join(pkg_dir, file)) or ""

                    if content:match("func%s+main%s*%(") then
                        table.insert(candidates, pkg_dir)

                        break
                    end
                end

                dir_handle:close()
            end
        end
    end

    list_handle:close()

    if #candidates == 0 then
        return root
    end

    table.sort(candidates, function(a, b)
        local _, count_a = a:gsub("[/\\]", "")
        local _, count_b = b:gsub("[/\\]", "")

        if count_a == count_b then
            return a < b
        end

        return count_a < count_b
    end)

    return candidates[1]
end

function _M.read_line(prompt, default)
    io.write(prompt)
    io.flush()

    local input = _M.trim(io.read("*l") or "")

    return input ~= "" and input or default
end

function _M.printf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("\x1b[37m%s\x1b[0m", format))
end

function _M.successf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("\x1b[32msuccess: %s\x1b[0m", format))
end

function _M.errorf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("\x1b[33merror: %s\x1b[0m", format))
end

return _M