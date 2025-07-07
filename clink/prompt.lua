local normal = "\x1b[m"
local blue = "\x1b[0;34m"
local yellow = "\x1b[0;33m"
local green = "\x1b[0;32m"
local red = "\x1b[0;31m"

local prompt = clink.promptfilter(30)

function prompt:filter(prompt)
    local errorlevel = tonumber(os.getenv("ERRORLEVEL"))
    local username = os.getenv("USERNAME")

    local arrows = false

    if errorlevel == 0 then
        arrows = green .. "❯❯ " .. normal
    elseif errorlevel then
        arrows = red .. "❯❯ " .. normal
    else
        arrows = yellow .. "❯❯ " .. normal
    end

    return blue .. username .. normal .. "@" .. yellow .. "[" .. blue .. prompt .. yellow .. "] " .. arrows
end

function welcome_message()
    local handle = io.popen("hostname")
    local hostname = handle:read("*a")
    handle:close()

    hostname = hostname:gsub("%s+", "")

    local current_time = os.date("%A, %d %b %Y, %I:%M %p")

    print(" \\    /\\ ")
    print("  )  ( ')  " .. green .. hostname .. normal)
    print(" (  /  )   " .. current_time)
    print("  \\(__)|\n")
end

welcome_message()
