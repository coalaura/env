-- helpers / utils

local function exists(path)
    local handle = io.open(path, "r")

    if not handle then
        return false
    end

    handle:close()

    return true
end

-- custom commands

local function push_command(args)
    local original_dir = os.getcwd()

    local target_dir = original_dir

    if #args > 0 then
        target_dir = args[1]
    end

    if not exists(target_dir .. "\\.git") then
        print("not a valid git repository")

        return
    end

    os.chdir(target_dir)

    os.execute("git add -A")
    os.execute("git commit -am \"update\"")
    os.execute("git push")

    os.chdir(original_dir)
end

clink.register_command("push", push_command)
clink.argmatcher("push"):addarg(clink.dirmatches)

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
