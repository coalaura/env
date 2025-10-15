local utils = require("utils")

-- core functions

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
    os.execute("sc start ssh-agent >nul 2>&1")

    local keys = {
        path.join(utils.home(), ".ssh\\keys\\github")
    }

    for _, key in ipairs(keys) do
        if utils.exists(key) then
            os.execute(string.format("ssh-add \"%s\" >nul 2>&1", key))
        end
    end

end

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

-- initialize other aliases
os.setalias("clear", "cls")

os.setalias("grep", "grep --color=auto $*")
os.setalias("ls", "ls --color=auto $*")
os.setalias("ll", "ls --color=auto -l $*")
os.setalias("la", "ls --color=auto -la $*")
os.setalias("..", "cd ..")

-- sign pushes, commits and tags
os.execute("git config --global gpg.format ssh")
os.execute(string.format("git config --global user.signingkey \"%s\"", path.join(utils.home(), ".ssh\\keys\\github")))
os.execute("git config --global push.gpgSign true")
os.execute("git config --global commit.gpgSign true")
os.execute("git config --global tag.gpgSign true")

-- print welcome message
print(" \\    /\\ ")
print("  )  ( ')  \x1b[0;32m" .. utils.hostname() .. "\x1b[0m")
print(" (  /  )   \x1b[0;35m" .. os.date("%A, %d %b %Y, %I:%M %p") .. "\x1b[0m")
print("  \\(__)|\n")

-- load starship
load(io.popen("starship init cmd"):read("*a"))()
