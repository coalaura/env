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

--
-- Shell settings
--

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

-- initialized environment variables
os.setenv("CC", "zig cc")
os.setenv("CXX", "zig c++")

-- initialize other aliases
os.setalias("clear", "cls")

os.setalias("ls", "coreutils ls --color=auto $*")
os.setalias("ll", "coreutils ls --color=auto -l $*")
os.setalias("la", "coreutils ls --color=auto -la $*")
os.setalias("tidy", "go mod tidy")
os.setalias("..", "cd ..")
os.setalias("...", "cd ..\\..")
os.setalias("home", string.format("cd %s", utils.escape_path(utils.home())))

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
