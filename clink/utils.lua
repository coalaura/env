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

function _M.escape_path(pt)
    pt = path.normalise(pt)

    pt = pt:gsub("[/\\]+$", "")
    pt = pt:gsub("\"", "\"\"")

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
    pt = pt:gsub("\"", "\"\"")

    local base = path.getbasename(pt)

    base = base:gsub("[ \t\\/]", "")

    if base == "" then
        return false
    end

    return base
end

function _M.parse_target_os(args)
    args = _M.trim(args or "")

    local words = {}

    for word in args:gmatch("%S+") do
        table.insert(words, word)
    end

    if #words == 0 then
        return "linux", false
    end

    local target = false

    local last = words[#words]:lower()

    if last == "win" or last == "windows" then
        target = "windows"
    elseif last == "lin" or last == "linux" then
        target = "linux"
    elseif last == "dar" or last == "darwin" then
        target = "darwin"
    end

    if not target then
        if args == "" then
            args = false
        end

        return "linux", args
    end

    table.remove(words, #words)

    if #words > 0 then
        args = table.concat(words, " ")
    else
        args = false
    end

    return target, args
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

function _M.read_line(prompt, default)
    io.write(prompt)
    io.flush()

    local input = _M.trim(io.read("*l") or "")

    return input ~= "" and input or default
end

function _M.printf(format, ...)
    print("\x1b[37m" .. string.format(format, ...))
end

function _M.successf(format, ...)
    print("\x1b[32msuccess: " .. string.format(format, ...))
end

function _M.errorf(format, ...)
    print("\x1b[33merror: " .. string.format(format, ...))
end

return _M