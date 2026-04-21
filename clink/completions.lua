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
