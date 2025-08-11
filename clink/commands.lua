-- helper functions

local function clean(str)
    local full = os.getfullpathname(str) or path.normalize(str)

    return rl.collapsetilde(full)
end

local function logf(format, ...)
    print(string.format(format, ...))
end

-- custom commands

local commands = {}

commands["pull"] = function(args)
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

clink.argmatcher("pull"):addarg(clink.dirmatches)

commands["push"] = function(args)
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

clink.argmatcher("push"):addarg(clink.dirmatches)

-- command handler

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
