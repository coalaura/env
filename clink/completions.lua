local utils = require("utils")

-- complete ssh command
local function get_ssh_hosts()
    local config_path = utils.join(utils.home(), ".ssh", "config")

    local hosts = {}
    local seen = {}

    if not os.isfile(config_path) then
        return hosts
    end

    local handle = io.open(config_path, "r")

    if not handle then
        return hosts
    end

    for line in handle:lines() do
        local host = line:match("^%s*[Hh][Oo][Ss][Tt]%s+(.+)$")

        if host then
            for name in host:gmatch("%S+") do
                if not name:match("[%*%?]") and not seen[name] and string.lower(name) ~= "github.com" then
                    seen[name] = true

                    table.insert(hosts, name)
                end
            end
        end
    end

    handle:close()

    return hosts
end

clink.argmatcher("ssh"):addarg(get_ssh_hosts)

-- command filter extension completions
local function filter_completions(command, extensions)
    local ext_set = {}

    for _, ext in ipairs(extensions) do
        ext_set[ext:lower()] = true
    end

    clink.argmatcher(command):addarg(function(word)
        word = word or ""

        local matches = {}
        local seen = {}

        local dir = "."
        local prefix = word
        local path_prefix = ""

        local last_sep = word:match(".*[\\/]")

        if last_sep then
            dir = word:sub(1, #last_sep - 1)

            path_prefix = last_sep

            prefix = word:sub(#last_sep + 1)

            if dir == "" then
                dir = "/"
            end
        end

        if dir:sub(1, 1) == "~" then
            dir = utils.home() .. dir:sub(2)
        end

        if dir == "" then
            dir = "."
        end

        local pattern = path.join(dir, "*")
        local files = os.globfiles(pattern) or {}

        for _, name in ipairs(files) do
            local lower_file = name:lower()
            local lower_prefix = prefix:lower()

            if lower_file:sub(1, #lower_prefix) == lower_prefix then
                local full_path = path.join(dir, name)
                local is_dir = os.isdir(full_path)

                local include = is_dir

                if not is_dir then
                    local ext = name:match("%.([^%.]+)$")

                    include = ext and ext_set[ext:lower()]
                end

                if include and not seen[lower_file] then
                    seen[lower_file] = true

                    table.insert(matches, path_prefix .. name)
                end
            end
        end

        return matches
    end)
end

filter_completions("sqlite3", {"db"})
