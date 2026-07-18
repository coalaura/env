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

    os.execute(string.format("git.exe -C %s add -A", escaped_root))

    if os.execute(string.format("git.exe -C %s diff-index --quiet HEAD -- 2>nul", escaped_root)) then
        utils.errorf("nothing to commit")

        return
    end

    os.execute(string.format("git.exe -C %s status -sb", escaped_root))

    local msg = utils.read_line("message: ", "update")

    utils.printf("pushing %s", utils.clean_path(root))

    os.execute(string.format("git.exe -C %s commit -m \"%s\"", escaped_root, utils.escape_input(msg)))
    os.execute(string.format("git.exe -C %s push", escaped_root))
end

clink.argmatcher("push"):addarg(clink.dirmatches)

-- create and push a git tag
commands["tag"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local escaped_root = utils.escape_path(root)
    local lines = utils.git_tag_lines(root, 1)

    if lines and #lines > 0 then
        local last_tag, last_msg = utils.parse_git_tag_line(lines[1])

        utils.printf("current: %s", last_tag)
        utils.subf("%s", last_msg)
    else
        utils.printf("current: n/a")
    end

    utils.printf("")

    local tag_name = utils.read_line("new tag: ", "")

    tag_name = utils.trim(tag_name)

    if tag_name == "" then
        utils.errorf("tag name is required")

        return
    end

    local msg = utils.read_line("message: ", "")

    msg = utils.trim(msg)

    if msg == "" then
        utils.errorf("message is required")

        return
    end

    local escaped_msg = utils.escape_input(msg)

    utils.printf("tagging %s as %s", utils.clean_path(root), tag_name)

    local cmd = string.format(
        "git.exe -C %s tag -a %s -m \"%s\"",
        escaped_root,
        tag_name,
        escaped_msg
    )

    if not os.execute(cmd) then
        utils.errorf("failed to create tag")

        return
    end

    utils.printf("pushing tag %s", tag_name)

    cmd = string.format("git.exe -C %s push origin %s", escaped_root, tag_name)

    if not os.execute(cmd) then
        utils.errorf("failed to push tag")

        return
    end

    utils.successf("tagged and pushed %s", tag_name)
end

clink.argmatcher("tag"):addarg(clink.dirmatches)

-- delete and push-delete a git tag
commands["dtag"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local lines = utils.git_tag_lines(root, 1)

    if not lines or #lines == 0 then
        utils.errorf("no tags found")

        return
    end

    local current_tag, current_msg = utils.parse_git_tag_line(lines[1])

    utils.printf("current: %s", current_tag)
    utils.subf("%s", current_msg)
    utils.printf("")

    local delete_name = utils.read_line("delete tag: ", "")

    delete_name = utils.trim(delete_name)

    if delete_name == "" then
        utils.errorf("tag name is required")

        return
    end

    local escaped_root = utils.escape_path(root)

    utils.printf("deleting %s from %s", delete_name, utils.clean_path(root))

    local cmd = string.format(
        "git.exe -C %s push origin :refs/tags/%s",
        escaped_root,
        delete_name
    )

    if not os.execute(cmd) then
        utils.errorf("failed to delete remote tag")

        return
    end

    cmd = string.format("git.exe -C %s tag -d %s", escaped_root, delete_name)

    if not os.execute(cmd) then
        utils.errorf("failed to delete local tag")

        return
    end

    utils.successf("deleted and pushed %s", delete_name)
end

clink.argmatcher("dtag"):addarg(clink.dirmatches)

-- delete, recreate, and push a git tag
commands["rtag"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local lines = utils.git_tag_lines(root, 1)

    if not lines or #lines == 0 then
        utils.errorf("no tags found")

        return
    end

    local current_tag, current_msg = utils.parse_git_tag_line(lines[1])

    utils.printf("current: %s", current_tag)
    utils.subf("%s", current_msg)
    utils.printf("")

    local tag_name = utils.read_line("re-tag: ", "")

    tag_name = utils.trim(tag_name)

    if tag_name == "" then
        utils.errorf("tag name is required")

        return
    end

    local escaped_root = utils.escape_path(root)

    -- get existing tag message
    local handle = io.popen(string.format("git.exe -C %s tag -l --format=\"%%(contents:subject)\" \"%s\" 2>nul", escaped_root, utils.escape_input(tag_name)))
    local msg = ""

    if handle then
        msg = utils.trim(handle:read("*a") or "")

        handle:close()
    end

    if msg == "" then
        msg = "update " .. tag_name
    end

    local escaped_msg = utils.escape_input(msg)

    utils.printf("deleting %s from %s", tag_name, utils.clean_path(root))

    local cmd = string.format(
        "git.exe -C %s push origin :refs/tags/%s",
        escaped_root,
        tag_name
    )

    if not os.execute(cmd) then
        utils.errorf("failed to delete remote tag")

        return
    end

    cmd = string.format("git.exe -C %s tag -d %s", escaped_root, tag_name)

    if not os.execute(cmd) then
        utils.errorf("failed to delete local tag")

        return
    end

    utils.printf("tagging %s as %s", utils.clean_path(root), tag_name)

    cmd = string.format(
        "git.exe -C %s tag -a %s -m \"%s\"",
        escaped_root,
        tag_name,
        escaped_msg
    )

    if not os.execute(cmd) then
        utils.errorf("failed to create tag")

        return
    end

    utils.printf("pushing tag %s", tag_name)

    cmd = string.format("git.exe -C %s push origin %s", escaped_root, tag_name)

    if not os.execute(cmd) then
        utils.errorf("failed to push tag")

        return
    end

    utils.successf("re-tagged and pushed %s", tag_name)
end

clink.argmatcher("rtag"):addarg(clink.dirmatches)

-- list recent tags with first message lines
commands["tags"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local lines, list_err = utils.git_tag_lines(root, 5)

    if not lines then
        utils.errorf(list_err or "failed to list tags")

        return
    end

    if #lines == 0 then
        utils.errorf("no tags found")

        return
    end

    for _, line in ipairs(lines) do
        local tag_name, tag_msg = utils.parse_git_tag_line(line)

        utils.printf("%s", tag_name)
        utils.subf("%s", tag_msg)
        utils.printf("")
    end
end

clink.argmatcher("tags"):addarg(clink.dirmatches)

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

-- reset and cleans git repo
commands["trash"] = function(args)
    local target_dir = args or os.getcwd()

    local root = utils.git_root(target_dir)

    local ok, err = utils.is_git(root)

    if not ok then
        utils.errorf(err)

        return
    end

    local msg = utils.read_line("trash everything? [y/N] ", "n")

    if msg ~= "y" and msg ~= "Y" then
        utils.errorf("aborted")

        return
    end

    local escaped_root = utils.escape_path(root)

    utils.printf("aborting pending operations...")

    os.execute(string.format("git.exe -C %s rebase --abort 2>nul", escaped_root))
    os.execute(string.format("git.exe -C %s merge --abort 2>nul", escaped_root))
    os.execute(string.format("git.exe -C %s cherry-pick --abort 2>nul", escaped_root))
    os.execute(string.format("git.exe -C %s bisect reset 2>nul", escaped_root))

    utils.printf("resetting...")

    if not os.execute(string.format("git.exe -C %s reset --hard", escaped_root)) then
        utils.errorf("failed to reset")

        return
    end

    utils.printf("cleaning...")

    if not os.execute(string.format("git.exe -C %s clean -fd", escaped_root)) then
        utils.errorf("failed to clean")

        return
    end

    utils.successf("cleaned")
end

clink.argmatcher("trash"):addarg(clink.dirmatches)

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

-- profile a project
commands["profile"] = function(args)
    local target_dir = os.getcwd()

    local focus = ""

    if args and args ~= "" then
        local first_word = args:match("^(%S+)")

        if first_word and first_word:sub(1, 1) ~= "-" then
            focus = first_word

            args = args:sub(#first_word + 1)
        end
    end

    local extra_args = utils.format_extra_args(args)

    if utils.is_go(target_dir) then
        if not utils.go_generate(target_dir) then
            return
        end

        local go_env = utils.prepare_go_env("windows", "amd64", extra_args)

        os.execute("rmdir /s /q .profile 2>nul")
        os.execute("mkdir .profile 2>nul")

        if focus ~= "" then
            utils.printf("[go] profiling %s (focus: %s)", utils.clean_path(target_dir), focus)

            os.execute(utils.command_with_env(string.format("go build -gcflags=\"-m -m\" ./... 2>&1 | findstr /I \"%s\" > .profile\\escape_analysis.txt", focus), go_env.env))
            os.execute(utils.command_with_env(string.format("go build -gcflags=\"-d=ssa/check_bce/debug=1\" ./... 2>&1 | findstr /I \"%s\" > .profile\\bce.txt", focus), go_env.env))
        else
            utils.printf("[go] profiling %s", utils.clean_path(target_dir))

            os.execute(utils.command_with_env("go build -gcflags=\"-m\" ./... > .profile\\escape_analysis.txt 2>&1", go_env.env))
            os.execute(utils.command_with_env("go build -gcflags=\"-d=ssa/check_bce/debug=1\" ./... > .profile\\bce.txt 2>&1", go_env.env))
        end

        os.execute(utils.command_with_env(
            string.format("go test -run=^$ -bench=. -benchmem -cpuprofile=.profile\\cpu.prof -memprofile=.profile\\mem.prof -mutexprofile=.profile\\mutex.prof -blockprofile=.profile\\block.prof -goroutineleakprofile=.profile\\goroutineleak.prof -trace=.profile\\trace.out %s %s ./... > .profile\\bench.txt 2>&1", go_env.tags_str, go_env.extra_args),
            go_env.env
        ))

        utils.successf("profile complete")
        utils.subf("escape/inline:   .profile\\escape_analysis.txt")
        utils.subf("bce misses:      .profile\\bce.txt")
        utils.subf("benchmarks:      .profile\\bench.txt")
        utils.subf("cpu profile:     go tool pprof -http=:8080 .profile\\cpu.prof")
        utils.subf("mem profile:     go tool pprof -http=:8081 .profile\\mem.prof")
        utils.subf("mutex blocks:    go tool pprof -http=:8082 .profile\\mutex.prof")
        utils.subf("goroutine leaks: go tool pprof -http=:8083 .profile\\goroutineleak.prof")
        utils.subf("trace ui:        go tool trace .profile\\trace.out")

        return
    end

    utils.errorf("%s is not a recognized profile project", utils.clean_path(target_dir))
end

-- benchmark a project
commands["bench"] = function(args)
    local cwd = os.getcwd()

    local parsed = utils.parse_args("bench", {"go", "js"}, false, true, args)

    if not parsed then
        return ""
    end

    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)
    local build_opts = parsed.opts

    local build_opts_str = table.concat(build_opts, " ")
    local go_args = build_opts_str .. " " .. pass_args

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("bench", cwd)
    end

    local project_dir, run_target = utils.resolve_project_target("bench", cwd, parsed.target, target_lang)

    if target_lang == "script" then
        local bench_cmd = path.join(project_dir, "bench.cmd")

        utils.printf("[bench.cmd] benchmarking %s", utils.clean_path(project_dir))

        return string.format("call %s %s", utils.escape_path(bench_cmd), pass_args)
    elseif target_lang == "go" then
        if not utils.go_generate(project_dir) then
            return ""
        end

        local packages = run_target and utils.escape_path(run_target) or "./..."

        local go_env = utils.prepare_go_env("windows", "amd64", go_args)

        utils.printf("[go] benchmarking %s (mode: %s)", utils.clean_path(run_target or project_dir), go_env.mode)

        return utils.command_with_env(
            string.format("go test -run=^$ -bench=. -benchmem %s %s %s", go_env.tags_str, go_env.extra_args, packages),
            go_env.env
        )
    elseif target_lang == "js" then
        if run_target and os.isfile(run_target) then
            utils.printf("[bun] benchmarking %s", utils.clean_path(run_target))

            return string.format("bun %s %s", utils.escape_path(run_target), pass_args)
        end

        if utils.is_node(project_dir) then
            local packageJson = path.join(project_dir, "package.json")
            local script = utils.get_package_json_script(packageJson, {"bench", "benchmark"})

            if script then
                utils.printf("[bun/%s] benchmarking %s", script, utils.clean_path(project_dir))

                return string.format("bun run %s %s", script, pass_args)
            end
        end

        -- fallback standalone bench files
        local patterns = {"bench.js", "bench.ts", "benchmark.js", "benchmark.ts"}

        for _, pattern in ipairs(patterns) do
            if os.isfile(path.join(project_dir, pattern)) then
                utils.printf("[bun] benchmarking %s", utils.clean_path(project_dir))

                return string.format("bun %s %s", pattern, pass_args)
            end
        end

        utils.errorf("%s is not a recognized js bench project", utils.clean_path(project_dir))

        return ""
    else
        utils.errorf("%s is not a recognized benchmark project", utils.clean_path(project_dir))

        return ""
    end
end

-- test a project
commands["test"] = function(args)
    local cwd = os.getcwd()

    local parsed = utils.parse_args("test", {"go", "js"}, false, true, args)

    if not parsed then
        return ""
    end

    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)
    local build_opts = parsed.opts

    local build_opts_str = table.concat(build_opts, " ")
    local go_args = build_opts_str .. " " .. pass_args

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("test", cwd)
    end

    local project_dir, run_target = utils.resolve_project_target("test", cwd, parsed.target, target_lang)

    if target_lang == "script" then
        local test_cmd = path.join(project_dir, "test.cmd")

        utils.printf("[test.cmd] testing %s", utils.clean_path(project_dir))

        return string.format("call %s %s", utils.escape_path(test_cmd), pass_args)
    elseif target_lang == "go" then
        if not utils.go_generate(project_dir) then
            return ""
        end

        local go_env = utils.prepare_go_env("windows", "amd64", go_args)
        local packages = run_target and utils.escape_path(run_target) or "./..."

        utils.printf("[go] testing %s (mode: %s)", utils.clean_path(run_target or project_dir), go_env.mode)

        local cmd = string.format("go test -v %s %s %s", go_env.tags_str, go_env.extra_args, packages)

        utils.run_go_test_colorized(cmd, go_env.env)

        return ""
    elseif target_lang == "js" then
        if run_target and os.isfile(run_target) then
            utils.printf("[bun test] testing %s", utils.clean_path(run_target))

            return string.format("bun test %s %s", utils.escape_path(run_target), pass_args)
        end

        if utils.is_node(project_dir) then
            local packageJson = path.join(project_dir, "package.json")
            local script = utils.get_package_json_script(packageJson, {"test"})

            if script then
                utils.printf("[bun/%s] testing %s", script, utils.clean_path(project_dir))

                return string.format("bun run %s %s", script, pass_args)
            end
        end

        -- fallback to bun test if test files exist
        local patterns = {"index.test.js", "index.test.ts", "index.spec.js", "index.spec.ts", "main.test.js", "main.test.ts"}

        for _, pattern in ipairs(patterns) do
            if os.isfile(path.join(project_dir, pattern)) then
                utils.printf("[bun test] testing %s", utils.clean_path(project_dir))

                return string.format("bun test %s", pass_args)
            end
        end

        utils.errorf("%s is not a recognized js test project", utils.clean_path(project_dir))

        return ""
    else
        utils.errorf("%s is not a recognized test project", utils.clean_path(project_dir))

        return ""
    end
end

-- run a project
commands["run"] = function(args)
    local cwd = os.getcwd()

    local parsed = utils.parse_args("run", {"go", "js", "php"}, false, true, args)

    if not parsed then
        return ""
    end

    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)
    local build_opts = parsed.opts

    local build_opts_str = table.concat(build_opts, " ")
    local go_args = build_opts_str .. " " .. pass_args

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("run", cwd)
    end

    local project_dir, run_target = utils.resolve_project_target("run", cwd, parsed.target, target_lang)

    if target_lang == "script" then
        local run_cmd = path.join(project_dir, "run.cmd")

        utils.printf("[run.cmd] running %s", utils.clean_path(project_dir))

        return string.format("call %s %s", utils.escape_path(run_cmd), pass_args)
    elseif target_lang == "php" then
        local artisan = path.join(project_dir, "artisan")

        if os.isfile(artisan) then
            utils.printf("[php] running artisan serve")

            return string.format("php artisan serve --port=80 %s", pass_args)
        end

        utils.errorf("%s is not a recognized php project", utils.clean_path(project_dir))

        return ""
    elseif target_lang == "go" then
        if not utils.go_generate(project_dir) then
            return ""
        end

        local main_spec = run_target or utils.find_go_main_dir(project_dir)
        local go_env = utils.prepare_go_env("windows", "amd64", go_args)

        utils.printf("[go] running %s (mode: %s)", utils.clean_path(main_spec), go_env.mode)

        return utils.command_with_env(
            string.format("go run %s %s %s", go_env.tags_str, go_env.extra_args, utils.escape_path(main_spec)),
            go_env.env
        )
    elseif target_lang == "js" then
        if run_target and os.isfile(run_target) then
            utils.printf("[bun] running %s", utils.clean_path(run_target))

            return string.format("bun %s %s", utils.escape_path(run_target), pass_args)
        end

        if utils.is_node(project_dir) then
            local packageJson = path.join(project_dir, "package.json")
            local script = utils.get_package_json_script(packageJson, {"dev", "watch", "start", "test"})

            if script then
                utils.printf("[bun/%s] running %s", script, utils.clean_path(project_dir))

                return string.format("bun run %s %s", script, pass_args)
            end
        end

        -- handle single node files
        local script = utils.get_first_existing_file(project_dir, {"index.js", "main.js", "app.js"})

        if script then
            utils.printf("[bun/%s] running %s", script, utils.clean_path(project_dir))

            return string.format("bun %s %s", script, pass_args)
        end

        utils.errorf("%s is not a recognized js project", utils.clean_path(project_dir))

        return ""
    else
        utils.errorf("%s is not a recognized project", utils.clean_path(project_dir))

        return ""
    end
end

-- build a project
commands["build"] = function(args)
    local cwd = os.getcwd()

    local parsed = utils.parse_args("build", {"go", "js"}, true, true, args)

    if not parsed then
        return ""
    end

    local target_os = parsed.os or "windows"
    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)
    local build_opts = parsed.opts

    local build_opts_str = table.concat(build_opts, " ")
    local go_args = build_opts_str .. " " .. pass_args

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("build", cwd)
    end

    local project_dir, run_target = utils.resolve_project_target("build", cwd, parsed.target, target_lang)

    if target_lang == "script" then
        local build_cmd = path.join(project_dir, "build.cmd")

        utils.printf("[build.cmd] building %s", utils.clean_path(project_dir))

        return string.format("call %s %s", utils.escape_path(build_cmd), pass_args)
    elseif target_lang == "go" then
        local main_spec = run_target or utils.find_go_main_dir(project_dir)
        local base = utils.basename(project_dir) or "app"

        if target_os == "windows" then
            base = base .. ".exe"
        end

        if not utils.go_generate(project_dir) then
            return ""
        end

        local go_env = utils.prepare_go_env(target_os, "amd64", go_args)

        utils.printf("[go/%s/%s] building %s (mode: %s)", target_os, base, utils.clean_path(main_spec), go_env.mode)

        local cmd = string.format(
            "go build %s -ldflags \"%s\" %s -o %s %s",
            go_env.build_flags,
            go_env.ldflags,
            go_env.extra_args,
            utils.escape_path(base),
            utils.escape_path(main_spec)
        )

        local t0 = utils.start_timer()

        local result = os.execute(utils.command_with_env(cmd, go_env.env))
        local success = (result == true or result == 0)

        if success then
            utils.end_timer(t0, "built")

            if go_env.is_min then
                utils.printf("[upx] compressing %s", base)

                local t1 = utils.start_timer()

                local upx_res = os.execute(string.format(
                    "upx --best --lzma %s >nul 2>&1",
                    utils.escape_path(base)
                ))

                if upx_res == true or upx_res == 0 then
                    utils.end_timer(t1, "compressed")
                else
                    utils.errorf("upx compression failed or upx is not installed")
                end
            end
        end

        return ""
    elseif target_lang == "js" then
        if utils.is_node(project_dir) then
            local packageJson = path.join(project_dir, "package.json")
            local script = utils.get_package_json_script(packageJson, {"build", "prod"})

            if not script then
                utils.errorf("no script found in package.json")

                return ""
            end

            utils.printf("[bun/%s] building %s", script, utils.clean_path(project_dir))

            local t0 = utils.start_timer()

            local result = os.execute(string.format("bun run %s %s", script, pass_args))

            if result == true or result == 0 then
                utils.end_timer(t0)
            end

            return ""
        else
            utils.errorf("no package.json found for node build")

            return ""
        end
    else
        utils.errorf("%s is not a recognized project", utils.clean_path(project_dir))

        return ""
    end
end

clink.argmatcher("build"):addarg({"win", "windows", "lin", "linux", "dar", "darwin"})

-- vet/analyze a project for issues
commands["vet"] = function(args)
    local target_dir = os.getcwd()

    local parsed = utils.parse_args("vet", {"go", "js"}, false, false, args)

    if not parsed then
        return ""
    end

    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("vet", target_dir)
    end

    local cmd = ""

    if target_lang == "go" then
        utils.printf("[go] vetting %s", utils.clean_path(target_dir))

        cmd = "go vet " .. pass_args .. " ./..."
    elseif target_lang == "js" then
        utils.printf("[biome] vetting %s", utils.clean_path(target_dir))

        local config = path.join(utils.home(), "biome.json")

        cmd = string.format("biome check --reporter=summary --no-errors-on-unmatched --log-level=info --config-path=%s %s", utils.escape_path(config), pass_args)
    else
        utils.errorf("unknown or undetected project type to vet")

        return ""
    end

    local result = os.execute(cmd)

    if result == true or result == 0 then
        utils.successf("no issues found")
    end

    return ""
end

-- auto-fix/lint a project
commands["fix"] = function(args)
    local target_dir = os.getcwd()

    local parsed = utils.parse_args("fix", {"go", "js"}, false, false, args)

    if not parsed then
        return ""
    end

    local target_lang = parsed.lang
    local pass_args = utils.format_extra_args(parsed.pass)

    if not target_lang or target_lang == "" then
        target_lang = utils.detect_lang("fix", target_dir)
    end

    if target_lang == "go" then
        utils.printf("[go] fixing %s", utils.clean_path(target_dir))

        return string.format("go fix %s ./... && go fmt %s ./...", pass_args, pass_args)
    elseif target_lang == "js" then
        utils.printf("[biome] fixing %s", utils.clean_path(target_dir))

        local config = path.join(utils.home(), "biome.json")

        return string.format("biome check --write --reporter=summary --no-errors-on-unmatched --log-level=info --config-path=%s %s", utils.escape_path(config), pass_args)
    end

    utils.errorf("unknown or undetected project type to fix")

    return ""
end

clink.argmatcher("fix"):addarg({"go", "js", "ts", "node"})

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

-- update github actions in workflows
commands["ghup"] = function(args)
    local target_dir = args or os.getcwd()

    local githubDir = path.join(target_dir, ".github")
    local workflowDir = path.join(githubDir, "workflows")

    if not os.isdir(workflowDir) then
        utils.errorf("no workflows directory found at %s", utils.clean_path(workflowDir))

        return
    end

    local cmd = string.format("cmd /c \"cd /d \"%s\" && dir /b /a-d *.yml *.yaml 2>nul\"", workflowDir:gsub('"', '""'))
    local handle = io.popen(cmd)

    if not handle then
        utils.errorf("failed to read workflows directory")

        return
    end

    local total = 0
    local count = 0

    local rules = {
        -- Version bumps
        { action = "actions/checkout", old = "12345", new = "6" },
        { action = "actions/setup-go", old = "12345", new = "6" },
        { action = "actions/cache", old = "1234", new = "5" },
        { action = "actions/cache/restore", old = "1234", new = "5" },
        { action = "actions/cache/save", old = "1234", new = "5" },
        { action = "oven-sh/setup-bun", old = "1", new = "2" },
        { action = "biomejs/setup-biome", old = "1", new = "2" },
        { action = "actions/github-script", old = "123456", new = "7" },
        { action = "actions/upload-artifact", old = "45", new = "6" },
        { action = "actions/download-artifact", old = "4567", new = "8" },
        {
            action = "actions/setup-node",
            old = "12345",
            new = "6",
            cond = function(content)
                return not content:match("always%-auth%s*:")
            end
        },

        -- Deprecations / replacements
        { action = "goto-bus-stop/setup-zig", replace_with = "mlugg/setup-zig@v2" }
    }

    for filename in handle:lines() do
        local trimmed = utils.trim(filename)

        if trimmed ~= "" then
            total = total + 1

            local workflowPath = path.join(workflowDir, trimmed)
            local content = utils.read_file(workflowPath)

            if content then
                content = content:gsub("\r", "")

                local new_content = content
                local changed = false

                local function bump(action, old_majors, new_major)
                    local escaped = utils.escape_pattern(action)

                    -- Match action@vX in the middle of lines
                    local pattern_inline = string.format("(%s@v)([%s])([^%%.%%d])", escaped, old_majors)
                    local replace_inline = string.format("%%1%s%%3", new_major)

                    local content_inline, matches_inline = new_content:gsub(pattern_inline, replace_inline)

                    if matches_inline > 0 then
                        new_content = content_inline
                        changed = true
                    end

                    -- Match action@vX at the end of the file (EOF)
                    local pattern_eof = string.format("(%s@v)([%s])$", escaped, old_majors)
                    local replace_eof = string.format("%%1%s", new_major)

                    local content_eof, matches_eof = new_content:gsub(pattern_eof, replace_eof)

                    if matches_eof > 0 then
                        new_content = content_eof
                        changed = true
                    end
                end

                for _, rule in ipairs(rules) do
                    if not rule.cond or rule.cond(new_content) then
                        if rule.replace_with then
                            local escaped = utils.escape_pattern(rule.action)
                            local replaced_content, match_count

                            -- Match versioned action (e.g., action@v1)
                            replaced_content, match_count = new_content:gsub(escaped .. "@[%w%-_%.%/]+", rule.replace_with)

                            if match_count > 0 then
                                new_content = replaced_content
                                changed = true
                            end

                            -- Match unversioned action inline
                            replaced_content, match_count = new_content:gsub(escaped .. "([^%w%-_%.%/])", rule.replace_with .. "%1")

                            if match_count > 0 then
                                new_content = replaced_content
                                changed = true
                            end

                            -- Match unversioned action at EOF
                            replaced_content, match_count = new_content:gsub(escaped .. "$", rule.replace_with)

                            if match_count > 0 then
                                new_content = replaced_content
                                changed = true
                            end
                        else
                            bump(rule.action, rule.old, rule.new)
                        end
                    end
                end

                if changed and new_content ~= content then
                    utils.write_file(workflowPath, new_content)
                    utils.printf("updated %s", trimmed)

                    count = count + 1
                end
            end
        end
    end

    handle:close()

    if total == 0 then
        utils.printf("no workflows found to update")
    elseif count == 0 then
        utils.printf("all actions are up to date (%d files checked)", total)
    else
        utils.successf("updated actions in %d/%d workflow(s)", count, total)
    end
end

clink.argmatcher("ghup"):addarg(clink.dirmatches)

-- create an ssh tunnel for a specific port
commands["tunnel"] = function(args)
    if not args then
        utils.errorf("usage: tunnel <host> <port>")

        return
    end

    local host, port = args:match("^(%S+)%s+(%d+)$")

    if not host or not port then
        utils.errorf("usage: tunnel <host> <port>")

        return
    end

    utils.printf("starting tunnel :%s to %s:%s...", port, host, port)

    return string.format(
        "ssh -N -o ExitOnForwardFailure=yes -o PermitLocalCommand=yes -o LocalCommand=\"echo \x1b[32m::\x1b[0m tunnel opened on port %s\" -L %s:localhost:%s %s",
        port, port, port, utils.escape_input(host)
    )
end

-- unzips or untars an archive to a target directory
commands["unpack"] = function(args)
    if not args or args == "" then
        utils.errorf("usage: unpack <archive> [target_dir]")

        return
    end

    local parsed = utils.split_args(args)
    local filename = parsed[1]
    local dirname = parsed[2] or "."

    if not filename or filename == "" then
        utils.errorf("usage: unpack <archive> [target_dir]")

        return
    end

    if not os.isfile(filename) then
        utils.errorf("file '%s' not found", filename)

        return
    end

    local lower = filename:lower()
    local esc_file = utils.escape_path(filename)
    local esc_dir = utils.escape_path(dirname)
    local base = path.getbasename(filename)

    utils.printf("unpacking %s to %s", utils.clean_path(filename), utils.clean_path(dirname))

    local mkdir = string.format("if not exist %s mkdir %s", esc_dir, esc_dir)

    if lower:match("%.tar%.") or
        lower:match("%.tgz$") or
        lower:match("%.tbz2$") or
        lower:match("%.txz$") or
        lower:match("%.tar$") or
        lower:match("%.zip$")
    then
        return string.format(
            "%s && tar.exe -xf %s -C %s",
            mkdir,
            esc_file,
            esc_dir
        )
    end

    if lower:match("%.gz$") then
        local out = base:gsub("%.gz$", "")

        if utils.has_command("gzip.exe") then
            return string.format(
                "%s && gzip.exe -dkc %s > %s",
                mkdir,
                esc_file,
                utils.escape_path(path.join(dirname, out))
            )
        end

        if utils.has_command("coreutils.exe") then
            return string.format(
                "%s && coreutils gzip -dkc %s > %s",
                mkdir,
                esc_file,
                utils.escape_path(path.join(dirname, out))
            )
        end

        utils.errorf("gzip not found")

        return ""
    end

    if lower:match("%.bz2$") then
        local out = base:gsub("%.bz2$", "")

        if utils.has_command("bzip2.exe") then
            return string.format(
                "%s && bzip2.exe -dkc %s > %s",
                mkdir,
                esc_file,
                utils.escape_path(path.join(dirname, out))
            )
        end

        utils.errorf("bzip2 not found")

        return ""
    end

    if lower:match("%.xz$") then
        local out = base:gsub("%.xz$", "")

        if utils.has_command("xz.exe") then
            return string.format(
                "%s && xz.exe -dkc %s > %s",
                mkdir,
                esc_file,
                utils.escape_path(path.join(dirname, out))
            )
        end

        utils.errorf("xz not found")

        return ""
    end

    if lower:match("%.zst$") then
        local out = base:gsub("%.zst$", "")

        if utils.has_command("zstd.exe") then
            return string.format(
                "%s && zstd.exe -dqc %s -o %s",
                mkdir,
                esc_file,
                utils.escape_path(path.join(dirname, out))
            )
        end

        utils.errorf("zstd not found")

        return ""
    end

    utils.errorf("unsupported or unrecognized archive format '%s'", filename)

    return ""
end

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

-- trigger terminal bell
commands["beep"] = function()
    ---@diagnostic disable-next-line banned-symbol
    print("\7")
end

-- safer rm that confirms folder deletes
commands["rm"] = function(args)
    if not args or args == "" then
        return "coreutils rm"
    end

    local parsed = utils.split_args(args)
    local parsing_opts = true

    for _, argument in ipairs(parsed) do
        local continue = false

        if parsing_opts then
            if argument == "--" then
                parsing_opts = false

                continue = true
            elseif argument:sub(1, 1) == "-" then
                continue = true
            end
        end

        if not continue and os.isdir(argument) then
            local reply = utils.read_line(
                string.format("remove \x1b[36m%s\x1b[0m? [y/N] ", argument),
                "n"
            )

            if reply ~= "y" and reply ~= "Y" then
                utils.errorf("rm aborted")

                return ""
            end
        end
    end

    return string.format("coreutils rm %s", args)
end

clink.argmatcher("rm"):addarg(clink.filematches)

-- update env
commands["envup"] = function()
    local env_dir = path.join(utils.home(), "env")

    if not os.isdir(env_dir) then
        utils.errorf("env directory not found")

        return
    end

    utils.printf("updating env in %s", utils.clean_path(env_dir))

    return string.format("cd /d %s && setup.cmd", utils.escape_path(env_dir))
end

-- Command handler
clink.onfilterinput(function(text)
    if not text then
        return
    end

    local command, arguments = text:match("^(%S+)%s*(.*)$")

    local isDebug = false

    if command == "debug" then
        isDebug = true

        command, arguments = (arguments or ""):match("^(%S+)%s*(.*)$")
    end

    if not command then
        return
    end

    arguments = utils.trim(arguments)

    if arguments == "" then
        arguments = nil
    end

    -- handle .command shorthand for local executables
    local name = command:match("^%.([%w_%-]+)$")

    if name then
        local cwd = os.getcwd()

        for _, ext in ipairs({".exe", ".cmd", ".bat"}) do
            local full_path = path.join(cwd, name .. ext)

            if os.isfile(full_path) then
                utils.printf("running .\\%s%s", name, ext)

                local extra = arguments and (" " .. arguments) or ""

                return "call " .. utils.escape_path(full_path) .. extra
            end
        end

        utils.errorf("no executable found for %s", name)

        return ""
    end

    local func = commands[command]

    if not func then
        return
    end

    local result = func(arguments)

    if isDebug then
        utils.printf("$ %s", result or "n/a")

        return ""
    end

    return result or ""
end)
