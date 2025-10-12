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
    return os.isdir(path.join(dir, ".git"))
end

function _M.is_go(dir)
    return os.isfile(path.join(dir, "go.mod"))
end

function _M.git_root(dir)
    local handle = io.popen(string.format("git -C \"%s\" rev-parse --show-toplevel 2>nul", dir))

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
    local handle = io.popen(string.format("git -C \"%s\" remote get-url origin 2>nul", dir))

    if not handle then
        return false
    end

    local url = handle:read("*l")

    handle:close()

    if not url or url == "" then
        return false
    end

    return url
end

function _M.clean_path(path)
    return rl.collapsetilde(path, true)
end

function _M.trim(str)
    return (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function _M.escape(str)
    return (str or ""):gsub('"', '\\"')
end

function _M.read_line(prompt, default)
    io.write(prompt)
    io.flush()

    local msg = _M.trim(io.read("*l") or "")

    if msg == "" then
        return default
    end

    return msg
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