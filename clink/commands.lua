local utils = require("utils")

-- custom commands

local commands = {}

commands["git_root"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    local root = utils.git_root(target_dir)

    utils.printf("%s", root)
end

clink.argmatcher("git_root"):addarg(clink.dirmatches)

commands["pull"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    os.execute(string.format("git.exe -C \"%s\" pull --rebase", root))
end

clink.argmatcher("pull"):addarg(clink.dirmatches)

commands["push"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    if os.execute(string.format("git.exe -C \"%s\" diff-index --quiet HEAD --", root)) then
        utils.errorf("nothing to commit")

        return
    end

    os.execute(string.format("git.exe -C %s status -sb", root))

    local msg = utils.read_line("message: ", "update")

    msg = utils.escape(msg)

    os.execute(string.format("git.exe -C \"%s\" add -A", root))
    os.execute(string.format("git.exe -C \"%s\" commit -am \"%s\"", root, msg))
    os.execute(string.format("git.exe -C \"%s\" push", root))
end

clink.argmatcher("push"):addarg(clink.dirmatches)

commands["origin"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local url = utils.git_remote(root)

    if not url then
        utils.errorf("failed to get remote")

        return
    end

    utils.printf("origin: %s", url)
end

clink.argmatcher("origin"):addarg(clink.dirmatches)

commands["git_ssh"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local url = utils.git_remote(root)

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

    os.execute(string.format("git.exe -C \"%s\" remote set-url origin \"%s\"", root, ssh))

    utils.successf("set remote to %s", ssh)
end

clink.argmatcher("git_ssh"):addarg(clink.dirmatches)

commands["run"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    if not utils.is_go(target_dir) then
        utils.errorf("%s is not a go project.", utils.clean_path(target_dir))

        return
    end

    return string.format("go run \"%s\"", target_dir)
end

clink.argmatcher("run"):addarg(clink.dirmatches)

commands["goup"] = function(args)
    local target_dir = tostring(args or os.getcwd())

    if not utils.is_go(target_dir) then
        utils.errorf("%s is not a go project.", utils.clean_path(target_dir))

        return
    end

    local gov = false

    local handle = io.popen("go version")

    if handle then
        local version = handle:read("*l") or ""

        handle:close()

        gov = version:match("go([%d%.]+)") or ""
    end

    if gov == "" then
        utils.errorf("failed to detect go version.")

        return
    end

    os.execute(string.format("cmd /c \"(cd /d \"%s\" && go mod edit -go %s)\"", target_dir, gov))

    utils.successf("set go version to %s", gov)

    os.execute(string.format("cmd /c \"(cd /d \"%s\" && go get -u ./... && go mod tidy)\"", target_dir))

    utils.successf("updated packages")
end

clink.argmatcher("goup"):addarg(clink.dirmatches)

commands["bio"] = function(args)
    os.execute("biome check --write --reporter=summary --no-errors-on-unmatched")

    utils.successf("ran biome check")
end

clink.argmatcher("bio"):addarg(clink.dirmatches)

-- command handler

clink.onfilterinput(function(text)
    if not text then
        return
    end

    local command = text
    local arguments = ""

    local index = text:find(" ")

    if index then
        command = text:sub(1, index - 1)

        arguments = text:sub(index + 1)
        arguments = utils.trim(arguments)
    end

    if arguments == "" then
        arguments = false
    end

    local func = commands[command]

    if not func then
        return
    end

    return func(arguments) or ""
end)
