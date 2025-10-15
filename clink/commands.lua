local utils = require("utils")

local commands = {}

commands["git_root"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    utils.printf("%s", utils.clean_path(root))
end

clink.argmatcher("git_root"):addarg(clink.dirmatches)

commands["pull"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    utils.printf("pulling %s", utils.clean_path(root))

    return string.format("git.exe -C %s pull --rebase", utils.escape_path(root))
end

clink.argmatcher("pull"):addarg(clink.dirmatches)

commands["push"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local escaped_root = utils.escape_path(root)

    utils.printf("checking %s", utils.clean_path(root))

    if os.execute(string.format("git.exe -C %s diff-index --quiet HEAD -- 2>nul", escaped_root)) then
        utils.errorf("nothing to commit")

        return
    end

    os.execute(string.format("git.exe -C %s status -sb", escaped_root))

    local msg = utils.read_line("message: ", "update")

    utils.printf("pushing %s", utils.clean_path(root))

    os.execute(string.format("git.exe -C %s add -A", escaped_root))
    os.execute(string.format("git.exe -C %s commit -am \"%s\"", escaped_root, utils.escape_input(msg)))
    os.execute(string.format("git.exe -C %s push", escaped_root))
end

clink.argmatcher("push"):addarg(clink.dirmatches)

commands["origin"] = function(args)
    local target_dir = args or os.getcwd()

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
    local target_dir = args or os.getcwd()

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

    local ssh = url:gsub("^https://github%.com/([^/]+)/(.+)%.git", "git@github.com:%1/%2.git")

    if ssh == url then
        utils.errorf("already an ssh remote")

        return
    end

    os.execute(string.format("git.exe -C %s remote set-url origin \"%s\"", utils.escape_path(root), ssh))

    utils.successf("set remote to %s", ssh)
end

clink.argmatcher("git_ssh"):addarg(clink.dirmatches)

commands["run"] = function(args)
    local target_dir = args or os.getcwd()

    if not utils.is_go(target_dir) then
        utils.errorf("%s is not a go project.", utils.clean_path(target_dir))

        return
    end

    local normalized = path.normalise(target_dir)

    utils.printf("running %s", utils.clean_path(normalized))

    return string.format("go run -C %s .", utils.escape_path(normalized))
end

clink.argmatcher("run"):addarg(clink.dirmatches)

commands["goup"] = function(args)
    local target_dir = args or os.getcwd()

    if not utils.is_go(target_dir) then
        utils.errorf("%s is not a go project.", utils.clean_path(target_dir))

        return
    end

    local handle = io.popen("go version 2>nul")

    if not handle then
        utils.errorf("failed to detect go version.")

        return
    end

    local version_line = handle:read("*l") or ""

    handle:close()

    local gov = version_line:match("go([%d%.]+)")

    if not gov then
        utils.errorf("failed to detect go version.")

        return
    end

    local escaped_dir = utils.escape_path(target_dir)

    os.execute(string.format("go -C %s mod edit -go %s", escaped_dir, gov))

    utils.successf("set go version to %s", gov)

    os.execute(string.format("go -C %s get -u ./...", escaped_dir))
    os.execute(string.format("go -C %s mod tidy", escaped_dir))

    utils.successf("updated packages")
end

clink.argmatcher("goup"):addarg(clink.dirmatches)

commands["bio"] = function()
    local config = path.join(utils.home(), "biome.json")

    return string.format("biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path=%s", utils.escape_path(config))
end

clink.argmatcher("bio"):addarg(clink.dirmatches)

-- Command handler
clink.onfilterinput(function(text)
    if not text then
        return
    end

    local command, arguments = text:match("^(%S+)%s*(.*)$")

    if not command then
        return
    end

    arguments = utils.trim(arguments)

    if arguments == "" then
        arguments = nil
    end

    local func = commands[command]

    if not func then
        return
    end

    return func(arguments) or ""
end)