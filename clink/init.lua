local utils = require("utils")

--
-- Helper functions
--

local function init_coreutils()
    local pipe = io.popen("coreutils --list")

    if not pipe then
        utils.errorf("failed to initialize coreutils")

        return
    end

    for line in pipe:lines() do
        local cmd = line:match("^%s*(.-)%s*$")

        if cmd and cmd ~= "" and cmd ~= "coreutils" then
            os.setalias(cmd, string.format("coreutils %s $*", cmd))
        end
    end

    pipe:close()
end

local function init_openssh()
    local key = utils.escape_path(path.join(utils.home(), ".ssh\\keys\\github"))

    utils.background({
        "sc start ssh-agent >nul 2>&1",
        string.format("if exist %s ssh-add %s >nul 2>&1", key, key)
    })
end

local function add_to_path(dirs)
    local changed = false
    local current = os.getenv("PATH") or ""

    for _, dir in ipairs(dirs) do
        local escaped = dir:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")

        if not current:match("[;]" .. escaped .. "[;]") and not current:match("^" .. escaped .. "[;]") and not current:match("[;]" .. escaped .. "$") and current ~= dir then
            current = current .. ";" .. dir

            changed = true
        end
    end

    if changed then
        os.setenv("PATH", current)
    end
end

--
-- Shell settings
--

-- set title bar color
io.write("\x1b]11;#24273a\x07")
io.flush()

-- replace ~ with home directory
clink.onfilterinput(function(text)
    local index = string.find(text, " ~")

    if not index or index < 5 then
        return
    end

    return text:sub(1, index) .. utils.home() .. text:sub(index + 2)
end)

-- starship path
os.setenv("STARSHIP_CONFIG", path.join(utils.home(), ".config\\starship.toml"))

-- initialize coreutils
init_coreutils()

-- initialize openssh
init_openssh()

-- ensure paths
add_to_path({
    path.join(utils.home(), ".zig"),
    path.join(utils.home(), ".bin"),
})

-- initialized environment variables
os.setenv("CGO_ENABLED", "1")
os.setenv("CC", "zig cc -target x86_64-windows-gnu")
os.setenv("CXX", "zig c++ -target x86_64-windows-gnu")

-- initialize other aliases
os.setalias("clear", "cls")

os.setalias("ls", "coreutils ls --color=auto $*")
os.setalias("ll", "coreutils ls --color=auto -l $*")
os.setalias("la", "coreutils ls --color=auto -la $*")
os.setalias("tidy", "go mod tidy")
os.setalias("which", "where $*")
os.setalias("..", "cd ..")
os.setalias("...", "cd ..\\..")
os.setalias("home", string.format("cd %s", utils.escape_path(utils.home())))
os.setalias("t", utils.binary("time.exe", " $*"))

-- handle ..\ or ...\
clink.onfilterinput(function(text)
    if text:match("^%s*%.%.\\") then
        return text:gsub("^(%s*)%.%.\\", "%1cd ..\\")
    end
end)

clink.onfilterinput(function(text)
    if text:match("^%s*%.%.%.\\") then
        return text:gsub("^(%s*)%.%.%.\\", "%1cd ..\\..\\")
    end
end)

--
-- Git settings
--

os.execute("git config --global --replace-all include.path \"~/.config/.gitconfig_env\" \"^~/.config/.gitconfig_env$\"")

--
-- Startup
--

-- print welcome message
print(" \\    /\\ ")
print(string.format("  )  ( ')  \x1b[0;32m%s\x1b[0m", utils.hostname()))
print(string.format(" (  /  )   \x1b[0;35m%s\x1b[0m", os.date("%A, %d %b %Y, %I:%M %p")))
print("  \\(__)|\n")

-- init starship
load(io.popen("starship init cmd"):read("*a"))()
