---@diagnostic disable-next-line shadow-global
local json = require("json")

local _M = {}

local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
local host = os.getenv("COMPUTERNAME") or ""

function _M.home()
    return home
end

function _M.binary(name, suffix)
    local dir = path.join(home, ".bin")

    return path.join(dir, name) .. (suffix or "")
end

function _M.hostname()
    return host
end

function _M.exists(pt)
    return os.isdir(pt) or os.isfile(pt)
end

function _M.join(...)
    local final = false

    for _, part in ipairs({...}) do
        if final then
            final = path.join(final, part)
        else
            final = part
        end
    end

    return final
end

function _M.read_file(pt)
    local handle = io.open(pt, "rb")

    if not handle then
        return nil
    end

    local content = handle:read("*a")

    handle:close()

    return content
end

function _M.write_file(pt, data)
    local handle = io.open(pt, "w")

    if not handle then
        return
    end

    handle:write(data)
    handle:close()
end

function _M.list_workflow_files(dir)
    local files = {}
    local seen = {}

    local function add_matches(pattern)
        local matches = os.globfiles(pattern)

        if not matches then
            return
        end

        for _, pt in ipairs(matches) do
            local match = path.normalise(path.join(dir, pt))

            if not seen[match] then
                seen[match] = true

                table.insert(files, match)
            end
        end
    end

    add_matches(path.join(dir, "*.yml"))
    add_matches(path.join(dir, "*.yaml"))

    table.sort(files)

    return files
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

function _M.git_tag_lines(pRoot, pCount)
    local escaped_root = _M.escape_path(pRoot)
    local lines = {}

    local handle = io.popen(string.format(
        "git.exe -C %s tag -n1 --sort=-creatordate 2>nul",
        escaped_root
    ))

    if not handle then
        return nil, "failed to list tags"
    end

    for line in handle:lines() do
        local trimmed = _M.trim(line or "")

        if trimmed ~= "" then
            table.insert(lines, trimmed)
        end

        if #lines >= (pCount or 1) then
            break
        end
    end

    handle:close()

    return lines
end

function _M.parse_git_tag_line(pLine)
    local tag_name, tag_msg = (pLine or ""):match("^(%S+)%s+(.+)$")

    if not tag_name then
        tag_name = _M.trim(pLine or "")
        tag_msg = "(no tag message)"
    end

    tag_msg = _M.trim(tag_msg or "")

    if tag_name == "" then
        tag_name = "n/a"
    end

    if tag_msg == "" then
        tag_msg = "(no tag message)"
    end

    return tag_name, tag_msg
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

function _M.escape_pattern(str)
    return (str or ""):gsub("[%-%.%+%?%*%%%[%]%^%$%(%)]", "%%%1")
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

    local base = path.getbasename(pt)

    if not base or base == "" then
        return false
    end

    -- if there's a dot, discard the last part (e.g. .sh)
    if base:find("%.") then
        base = base:gsub("%.[^%.]*$", "")
    end

    -- normalize hyphens and remaining dots to underscores
    base = base:gsub("[%-%.]", "_")

    -- clean up any remaining invalid characters (spaces, etc.)
    base = base:gsub("[^%w_]", "")

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

function _M.subf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("   \x1b[90m-> %s\x1b[0m", format))
end

function _M.end_timer(start_time, action_name)
    action_name = action_name or "built"

    local elapsed = os.clock() - start_time

    if elapsed < 1.0 then
        _M.subf("%s in %dms", action_name, math.floor(elapsed * 1000))
    else
        _M.subf("%s in %.2fs", action_name, elapsed)
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

    local final_cmd = cmd

    if env then
        final_cmd = _M.command_with_env(cmd, env)
    end

    local gen_result = os.execute(final_cmd)

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

function _M.parse_args(cmd_name, allowed_langs, allow_os, allow_build_opts, args)
    local tokens = _M.split_args(args)

    local parsed = {
        lang = nil,
        os = nil,
        opts = {},
        pass = {}
    }

    local parsing_opts = true
    local allowed_langs_map = {}

    for _, lang in ipairs(allowed_langs) do
        allowed_langs_map[lang] = true
    end

    for _, token in ipairs(tokens) do
        if parsing_opts then
            local lower = token:lower()

            if token == "--" then
                parsing_opts = false
            elseif lower == "--pure" or lower == "--compat" or lower == "--min" then
                if allow_build_opts then
                    table.insert(parsed.opts, lower)
                else
                    _M.errorf("Unknown argument for %s: %s", cmd_name, lower)

                    return false
                end
            else
                local osOpt = false
                local langOpt = false

                if allow_os then
                    if lower == "win" or lower == "windows" then
                        osOpt = "windows"
                    elseif lower == "lin" or lower == "linux" then
                        osOpt = "linux"
                    elseif lower == "dar" or lower == "darwin" then
                        osOpt = "darwin"
                    end
                end

                if allowed_langs_map[lower] then
                    langOpt = lower
                end

                if osOpt then
                    parsed.os = osOpt
                elseif langOpt then
                    parsed.lang = langOpt
                else
                    _M.errorf("Unknown argument for %s: %s", cmd_name, token)

                    return false
                end
            end
        else
            table.insert(parsed.pass, token)
        end
    end

    return parsed
end

function _M.detect_lang(cmd_name, target)
    if cmd_name == "bench" or cmd_name == "test" or cmd_name == "run" or cmd_name == "build" then
        if os.isfile(path.join(target, cmd_name .. ".cmd")) then
            return "script"
        end
    end

    if cmd_name == "run" and os.isfile(path.join(target, "artisan")) then
        return "php"
    end

    if os.isfile(path.join(target, "go.mod")) then
        return "go"
    end

    if os.isfile(path.join(target, "package.json")) then
        return "js"
    end

    if cmd_name == "run" then
        for _, entry in ipairs({"index.js", "main.js", "app.js"}) do
            if os.isfile(path.join(target, entry)) then
                return "js"
            end
        end
    end

    return ""
end

function _M.format_extra_args(args)
    if not args or #args == 0 then
        return ""
    end

    if type(args) == "string" then
        return args
    end

    local escaped = {}

    for _, extraArg in ipairs(args) do
        table.insert(escaped, _M.escape_input(extraArg))
    end

    return " " .. table.concat(escaped, " ")
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

    local build_flags = "-trimpath -buildvcs=false"
    local ldflags = "-s -w"

    if is_pure then
        add_tags("netgo,osusergo")

        env.CGO_ENABLED = "0"
        env.CC = ""
        env.CXX = ""
    else
        env.CGO_ENABLED = "1"
    end

    local tags_str = ""

    if #merged_tags > 0 then
        tags_str = " -tags " .. table.concat(merged_tags, ",")

        build_flags = build_flags .. tags_str
    end

    if is_compat then
        env.GOAMD64 = "v1"
    else
        env.GOAMD64 = "v3"
    end

    -- always-enabled go experiments
    local goexperiments = {}
    local seen_exp = {}

    local function add_experiment(exp_str)
        for exp in tostring(exp_str or ""):gmatch("[^,%s]+") do
            if not seen_exp[exp] then
                seen_exp[exp] = true

                table.insert(goexperiments, exp)
            end
        end
    end

    add_experiment(os.getenv("GOEXPERIMENT"))
    add_experiment("jsonv2,goroutineleakprofile")

    env.GOEXPERIMENT = table.concat(goexperiments, ",")

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

        if zig_target then
            cflags = cflags .. " -target " .. zig_target
        end

        if target_arch == "amd64" then
            if is_compat then
                cflags = cflags .. " -march=x86_64"
            else
                cflags = cflags .. " -march=x86_64_v3"
            end
        end

        env.CGO_CFLAGS = cflags
        env.CGO_CXXFLAGS = cflags

        if zig_target then
            env.CGO_LDFLAGS = "-Wl,--gc-sections -target " .. zig_target
        else
            env.CGO_LDFLAGS = "-Wl,--gc-sections"
        end
    end

    return {
        env = env,
        build_flags = build_flags,
        ldflags = ldflags,
        extra_args = _M.trim(table.concat(passthrough, " ")),
        tags_str = _M.trim(tags_str),
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

    for _, script in ipairs(allowed) do
        if scripts[script] then
            return script
        end
    end

    return false
end

function _M.get_first_existing_file(dir, allowed)
    for _, filename in ipairs(allowed) do
        local pt = path.join(dir, filename)

        if os.isfile(pt) then
            return filename
        end
    end

    return false
end

function _M.find_go_main_dir(root)
    root = path.normalise(root)

    local handle = io.popen(string.format("dir /b \"%s\\*.go\" 2>nul", root))

    if handle then
        for filename in handle:lines() do
            local content = _M.read_file(path.join(root, filename)) or ""

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
                for filename in dir_handle:lines() do
                    local content = _M.read_file(path.join(pkg_dir, filename)) or ""

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

function _M.run_go_test_colorized(cmd, env)
    local full_cmd = _M.command_with_env(cmd .. " 2>&1", env)

    local handle = io.popen(full_cmd)

    if not handle then
        _M.errorf("failed to run tests")

        return false
    end

    for line in handle:lines() do
        local matched = false

        -- "=== RUN   TestName"
        local run_test = line:match("^=== RUN%s+(.*)")

        if run_test then
            line = string.format("   \x1b[90m-> run: \x1b[0m \x1b[36m%s\x1b[0m", run_test)

            matched = true
        end

        -- "--- PASS: TestName (0.00s)"
        if not matched then
            local pass_test, pass_time = line:match("^%s*%-%-%- PASS:%s+(%S+)%s+(%(.+%))")

            if pass_test then
                line = string.format("   \x1b[32m-> pass:\x1b[0m \x1b[36m%s\x1b[0m \x1b[90m%s\x1b[0m", pass_test, pass_time)

                matched = true
            end
        end

        -- "--- FAIL: TestName (0.00s)" or "    --- FAIL: SubTest (0.00s)"
        if not matched then
            local fail_test, fail_time = line:match("^%s*%-%-%- FAIL:%s+(%S+)%s+(%(.+%))")

            if fail_test then
                line = string.format("   \x1b[31m-> fail:\x1b[0m \x1b[31;1m%s\x1b[0m \x1b[90m%s\x1b[0m", fail_test, fail_time)

                matched = true
            end
        end

        -- "--- SKIP: TestName (0.00s)"
        if not matched then
            local skip_test, skip_time = line:match("^%s*%-%-%- SKIP:%s+(%S+)%s+(%(.+%))")

            if skip_test then
                line = string.format("   \x1b[33m-> skip:\x1b[0m \x1b[36m%s\x1b[0m \x1b[90m%s\x1b[0m", skip_test, skip_time)

                matched = true
            end
        end

        -- "ok      package/name   0.00s"
        if not matched then
            local ok_pkg, ok_time = line:match("^ok%s+(%S+)%s+(.*)")

            if ok_pkg then
                line = string.format("\x1b[32m::\x1b[0m \x1b[32mok\x1b[0m     %s \x1b[90m%s\x1b[0m", ok_pkg, ok_time)

                matched = true
            end
        end

        -- "FAIL    package/name   0.00s"
        if not matched then
            local fail_pkg, fail_time = line:match("^FAIL%s+(%S+)%s+(.*)")

            if fail_pkg then
                line = string.format("\x1b[31m!!\x1b[0m \x1b[31;1mFAIL\x1b[0m   %s \x1b[90m%s\x1b[0m", fail_pkg, fail_time)

                matched = true
            end
        end

        -- "?       package/name   [no test files]"
        if not matched then
            local q_pkg, q_time = line:match("^%?%s+(%S+)%s+(.*)")

            if q_pkg then
                line = string.format("\x1b[33m::\x1b[0m \x1b[33m?\x1b[0m      %s \x1b[90m%s\x1b[0m", q_pkg, q_time)

                matched = true
            end
        end

        -- Global final result flags
        if not matched then
            if line == "PASS" then
                line = "\x1b[32;1mPASS\x1b[0m"
            elseif line == "FAIL" then
                line = "\x1b[31;1mFAIL\x1b[0m"
            end
        end

        print(line)
    end

    return handle:close()
end

function _M.split_args(pArgs)
    local out = {}
    local argument = ""
    local quote = false
    local escaped = false

    pArgs = pArgs or ""

    for i = 1, #pArgs do
        local ch = pArgs:sub(i, i)

        if escaped then
            argument = argument .. ch
            escaped = false
        elseif ch == "^" then
            escaped = true
        elseif quote then
            if ch == quote then
                quote = nil
            else
                argument = argument .. ch
            end
        elseif ch == '"' or ch == "'" then
            quote = ch
        elseif ch:match("%s") then
            if argument ~= "" then
                table.insert(out, argument)

                argument = ""
            end
        else
            argument = argument .. ch
        end
    end

    if escaped then
        argument = argument .. "^"
    end

    if argument ~= "" then
        table.insert(out, argument)
    end

    return out
end

function _M.has_command(pCommand)
    local handle = io.popen(string.format("where %s 2>nul", pCommand))

    if not handle then
        return false
    end

    local line = handle:read("*l")

    handle:close()

    return line ~= nil and line ~= ""
end

function _M.path_has(pCurrent, pDir)
    local current = ";" .. (pCurrent or ""):lower() .. ";"
    local dir = (pDir or ""):lower():gsub("[/\\]+$", "")

    return current:find(";" .. dir:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. ";") ~= nil
end

function _M.read_line(prompt, default)
    io.write(string.format("\x1b[33m??\x1b[0m %s", prompt))
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

    if format == "" then
        print("")

        return
    end

    print(string.format("\x1b[36m::\x1b[0m %s", format))
end

function _M.successf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("\x1b[32m::\x1b[0m %s", format))
end

function _M.errorf(format, ...)
    if not format then
        return
    end

    if #{...} > 0 then
        format = string.format(format, ...)
    end

    print(string.format("\x1b[31m!!\x1b[0m %s", format))
end

return _M
