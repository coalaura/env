local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""

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

local function init_openssh()
    os.execute("sc start ssh-agent >nul 2>&1")

    local keys = {
        home .. "\\.ssh\\keys\\github"
    }

    for _, key in ipairs(keys) do
        local file = io.open(key, "r")

        if file ~= nil then
            file:close()

            os.execute("ssh-add \"" .. key .. "\" >nul 2>&1")
        end
    end

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

-- initialize openssh
init_openssh()

-- initialize other aliases
os.setalias("grep", "rg $*")
os.setalias("clear", "cls")

-- load starship
load(io.popen('starship init cmd'):read("*a"))()

-- welcome :)
welcome_message()
