local _M = {}

local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
local host = os.getenv("COMPUTERNAME") or ""

function _M.home()
    return home
end

function _M.hostname()
    return host
end

function _M.exists(path)
    return os.isdir(path) or os.isfile(path)
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

function _M.clean_path(p)
    return rl.collapsetilde(p, true)
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