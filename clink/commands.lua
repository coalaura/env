local utils = require("utils")

local commands = {}

commands["git_root"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    utils.printf("%s", utils.clean_path(root))
end

clink.argmatcher("git_root"):addarg(clink.dirmatches)

-- pull a given repo
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

-- add, commit and push a given repo
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

-- print git remote origin
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

-- convert https to ssh git repo
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

-- run a project
commands["run"] = function(args)
    local target_dir = args or os.getcwd()

    -- handle run script
    local run_cmd = path.join(target_dir, "run.cmd")

    if os.isfile(run_cmd) then
        utils.printf("[run.cmd] running %s", utils.clean_path(target_dir))

        return string.format(
            "pushd %s && call %s && popd",
            utils.escape_path(target_dir),
            utils.escape_path(run_cmd)
        )
    end

    -- handle go project
    if utils.is_go(target_dir) then
        utils.printf("[go] running %s", utils.clean_path(target_dir))

        return string.format("go run -C %s .", utils.escape_path(target_dir))
    end

    -- handle node project
    if utils.is_node(target_dir) then
        local package = path.join(target_dir, "package.json")

        local script = utils.get_package_json_script(package, {"dev", "watch", "start", "test"})

        if script then
            utils.printf("[bun/%s] running %s", script, utils.clean_path(target_dir))

            return string.format("bun run --cwd %s %s", utils.escape_path(target_dir), script)
        end
    end

    -- handle single node files
    local script = utils.get_first_existing_file(target_dir, {"index.js", "main.js", "app.js"})

    if script then
        utils.printf("[bun/%s] running %s", script, utils.clean_path(target_dir))

        return string.format("bun --cwd %s %s", utils.escape_path(target_dir), script)
    end

    utils.errorf("%s is not a recognized project", utils.clean_path(target_dir))
end

clink.argmatcher("run"):addarg(clink.dirmatches)

-- build a project
commands["build"] = function(args)
    local target_os, args = utils.parse_target_os(args)

    local target_dir = args or os.getcwd()

    -- handle build script
    local build_cmd = path.join(target_dir, "build.cmd")

    if os.isfile(build_cmd) then
        utils.printf("[build.cmd] building %s", utils.clean_path(target_dir))

        return string.format(
            "pushd %s && call %s && popd",
            utils.escape_path(target_dir),
            utils.escape_path(build_cmd)
        )
    end

    -- handle go project
    if utils.is_go(target_dir) then
        local base = utils.basename(target_dir) or "app"

        utils.printf("[go/%s/%s] building %s", target_os, base, utils.clean_path(target_dir))

        if target_os == "windows" then
            base = base .. ".exe"
        end

        return string.format(
            "set \"GOOS=%s\" && (go build -C %s -o %s && set \"GOOS=windows\") || set \"GOOS=windows\"",
            target_os,
            utils.escape_path(target_dir),
            base
        )
    end

    -- handle node project
    if utils.is_node(target_dir) then
        local package = path.join(target_dir, "package.json")

        local script = utils.get_package_json_script(package, {"build", "prod"})

        if not script then
            utils.errorf("no script found in package.json")

            return
        end

        utils.printf("[bun/%s] building %s", script, utils.clean_path(target_dir))

        return string.format(
            "bun run --cwd %s %s",
            utils.escape_path(target_dir),
            script
        )
    end

    utils.errorf("%s is not a recognized project")
end

clink.argmatcher("build"):addarg(clink.dirmatches):addarg({"win", "windows", "lin", "linux", "dar", "darwin"})

-- update a go project
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

-- run biome check
commands["bio"] = function(args)
    local config = path.join(utils.home(), "biome.json")

    return string.format("biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path=%s %s", utils.escape_path(config), args or "")
end

clink.argmatcher("bio"):addarg(clink.dirmatches)

-- download and run vencord installer
commands["vencord"] = function()
    local tmp = os.getenv("TMP") or os.getenv("TEMP") or utils.home()

    local out = path.join(tmp, "VencordInstallerCli.exe")

    os.remove(out)

    utils.printf("downloading installer")

    local ok = os.execute(string.format(
        "curl -L -f --silent --show-error -o %s \"https://github.com/Vencord/Installer/releases/latest/download/VencordInstallerCli.exe\" 2>nul",
        utils.escape_path(out)
    ))

    if not ok then
        utils.errorf("failed to download installer")

        os.remove(out)

        return
    end

    utils.printf("running installer")

    os.execute(utils.escape_path(out))

    os.remove(out)
end

-- create service configuration from templates
commands["mkconf"] = function(args)
    if not args then
        utils.errorf("usage: mkconf <path> <name>")

        return
    end

    local arg_path, arg_name = args:match("^(%S+)%s+(%S+)$")

    if not arg_path or not arg_name then
        utils.errorf("usage: mkconf <path> <name>")

        return
    end

    if arg_path:sub(1, 1) ~= "/" then
        utils.errorf("path must start with / (e.g. /opt/myapp)")

        return
    end

    local name = arg_name:lower()
    local nameUc = arg_name:gsub("^%l", string.upper)
    local clean_path = arg_path:gsub("[\\/]+$", "")

    local tpl_dir = path.join(utils.home(), "env/.templates/conf")
    local target_dir = path.join(os.getcwd(), "conf")

    os.execute(string.format("mkdir %s 2>nul", utils.escape_path(target_dir)))

    local files = {
        {
            src = "service.service",
            dst = string.format("%s.service", name)
        },
        {
            src = "user.conf",
            dst = string.format("%s.conf", name)
        },
        {
            src = "setup.sh",
            dst = "setup.sh"
        }
    }

    for id, file in ipairs(files) do
        local src_path = path.join(tpl_dir, file.src)
        local dst_path = path.join(target_dir, file.dst)

        local handleIn = io.open(src_path, "rb")

        if not handleIn then
            utils.errorf("template not found: %s", file.src)

            return
        end

        local content = handleIn:read("*a")

        handleIn:close()

        content = content:gsub("\r", "")

        content = content:gsub("%[Name%]", nameUc)
        content = content:gsub("%[name%]", name)
        content = content:gsub("%[path%]", clean_path)

        local handleOut = io.open(dst_path, "wb")

        if not handleOut then
            utils.errorf("failed to write: %s", file.src)

            return
        end

        handleOut:write(content)
        handleOut:close()

        utils.printf("created %s", file.dst)
    end

    utils.successf("config created")
end

clink.argmatcher("mkconf"):addarg(clink.dirmatches)

-- trigger terminal bell
commands["beep"] = function()
    print("\7")
end

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