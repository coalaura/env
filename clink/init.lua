-- helper functions

local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""

local function clean(str)
    local full = os.getfullpathname(str) or path.normalize(str)

    return rl.collapsetilde(full)
end

local function logf(format, ...)
    print(string.format(format, ...))
end

-- custom commands

local function pull_command(args)
    local original_dir = os.getcwd()

    local target_dir = original_dir

    if #args > 0 then
        target_dir = args
    end

    if not os.isdir(path.join(target_dir, ".git")) then
        print("error: not a valid git repository")

        return
    end

    logf("pulling: %s", clean(target_dir))

    os.chdir(target_dir)

    os.execute("git pull --rebase")

    os.chdir(original_dir)
end

local function push_command(args)
    local original_dir = os.getcwd()

    local target_dir = original_dir

    if #args > 0 then
        target_dir = args
    end

    if not os.isdir(path.join(target_dir, ".git")) then
        print("error: not a valid git repository")

        return
    end

    logf("pushing: %s", clean(target_dir))

    os.chdir(target_dir)

    os.execute("git add -A")
    os.execute("git commit -am \"update\"")
    os.execute("git push")

    os.chdir(original_dir)
end

clink.argmatcher("pull"):addarg(clink.dirmatches)
clink.argmatcher("push"):addarg(clink.dirmatches)

local commands = {
    ["pull"] = pull_command,
    ["push"] = push_command
}

clink.onfilterinput(function(text)
    if not text then
        return
    end

    local command = text
    local arguments = ""

    local index = text:find(" ")

    if index then
        command = text:sub(1, index-1)
        arguments = text:sub(index+1)
    end

    local func = commands[command]

    if not func then
        return
    end

    func(arguments)

    return ""
end)

-- core functions

local function init_coreutils()
    local pipe = io.popen("coreutils --list")

    if not pipe then
        print("\x1b[0;31mFailed to initialize coreutils!")

        return
    end

    for line in pipe:lines() do
        local cmd = line:match("^%s*(.-)%s*$")

        if cmd ~= "" and cmd ~= nil then
            if cmd ~= "coreutils" then
                os.setalias(cmd, "coreutils " .. cmd .. " $*")
            end
        end
    end

    pipe:close()
end

local function welcome_message()
    local handle = io.popen("hostname")
    local hostname = handle:read("*a")
    handle:close()

    hostname = hostname:gsub("%s+", "")

    local current_time = os.date("%A, %d %b %Y, %I:%M %p")

    print(" \\    /\\ ")
    print("  )  ( ')  \x1b[0;32m" .. hostname .. "\x1b[m")
    print(" (  /  )   " .. current_time)
    print("  \\(__)|\n")
end

-- replace ~ with home directory
clink.onfilterinput(function(text)
    local index = string.find(text, " ~")

    if not index or index < 5 then
        return
    end

    return text:sub(1, index) .. home .. text:sub(index + 2)
end)

-- starship path
os.setenv("STARSHIP_CONFIG", os.getenv("USERPROFILE") .. "\\.config\\starship.toml")

-- initialize coreutils
init_coreutils()

-- initialize other aliases
os.setalias("grep", "rg $*")
os.setalias("clear", "cls")

-- load starship
load(io.popen('starship init cmd'):read("*a"))()

-- welcome :)
welcome_message()
