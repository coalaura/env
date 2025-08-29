local utils = require("utils")

-- custom commands

local commands = {}

commands["pull"] = function(args)
    local target_dir = os.getcwd()

    if #args > 0 then
        target_dir = args
    end

    if not utils.is_git(target_dir) then
        utils.errorf("%s is not a git repository.", utils.clean_path(target_dir))

        return
    end

    os.execute(string.format("git -C %s pull --rebase", target_dir))
end

clink.argmatcher("pull"):addarg(clink.dirmatches)

commands["push"] = function(args)
    local target_dir = os.getcwd()

    if #args > 0 then
        target_dir = args
    end

    if not utils.is_git(target_dir) then
        utils.errorf("%s is not a git repository.", utils.clean_path(target_dir))

        return
    end

    if os.execute(string.format("git -C %s diff-index --quiet HEAD --", target_dir)) then
        utils.errorf("nothing to commit")

        return
    end

    os.execute(string.format("git -C %s status -sb", target_dir))

    local msg = utils.read_line("message: ", "update")

    msg = utils.escape(msg)

    os.execute(string.format("git -C %s add -A", target_dir))
    os.execute(string.format("git -C %s commit -am \"%s\"", target_dir, msg))
    os.execute(string.format("git -C %s push", target_dir))
end

clink.argmatcher("push"):addarg(clink.dirmatches)

commands["origin"] = function(args)
    local target_dir = os.getcwd()

    if #args > 0 then
        target_dir = args
    end

    if not utils.is_git(target_dir) then
        utils.errorf("%s is not a git repository.", utils.clean_path(target_dir))

        return
    end

    local url = utils.git_remote(target_dir)

    if not url then
        utils.errorf("failed to get remote")

        return
    end

    utils.printf("origin: %s", url)
end

clink.argmatcher("origin"):addarg(clink.dirmatches)

commands["git_ssh"] = function(args)
    local target_dir = os.getcwd()

    if #args > 0 then
        target_dir = args
    end

    if not utils.is_git(target_dir) then
        utils.errorf("%s is not a git repository.", utils.clean_path(target_dir))

        return
    end

    local url = utils.git_remote(target_dir)

    if not url then
        utils.errorf("failed to get remote")

        return
    end

    if not url:match("%.git$") then
        url = url .. ".git"
    end

    local ssh = url:gsub("^https://github.com/([^/]+)/(.+)%.git", "git@github.com:%1/%2.git")

    if ssh == url then
        utils.errorf("already an ssh remote")

        return
    end

    os.execute(string.format("git -C %s remote set-url origin %s", target_dir, ssh))

    utils.successf("set remote to %s", ssh)
end

clink.argmatcher("git_ssh"):addarg(clink.dirmatches)

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
