local utils = require("utils")

local _M = {}

function _M.register_windows_only_commands(commands)
	-- kill processes by name (case-insensitive)
	commands["pkill"] = function(args)
		if not args or args == "" then
			utils.errorf("usage: pkill <name> [name...]")

			return
		end

		local names = utils.split_args(args)
		local wanted = {}

		for _, name in ipairs(names) do
			local base = utils.trim(name):gsub("%.[eE][xX][eE]$", ""):lower()

			if base ~= "" then
				wanted[base] = true
			end
		end

		if not next(wanted) then
			utils.errorf("usage: pkill <name> [name...]")

			return
		end

		local handle = io.popen("tasklist /fo csv /nh 2>nul")

		if not handle then
			utils.errorf("failed to list processes")

			return
		end

		local by_image = {}
		local order = {}

		for line in handle:lines() do
			local img, pid = line:match('^"([^"]+)","(%d+)"')

			if img and pid then
				local img_lower = img:lower()
				local img_base = img_lower:gsub("%.exe$", "")

				if wanted[img_base] then
					if not by_image[img] then
						by_image[img] = {}

						table.insert(order, img)
					end

					table.insert(by_image[img], pid)
				end
			end
		end

		handle:close()

		if #order == 0 then
			utils.errorf("no matching process found")

			return
		end

		local killed = 0

		for _, img in ipairs(order) do
			local pids = by_image[img]

			utils.printf("killing \"\x1b[36m%s\x1b[0m\" (%d process%s)", img, #pids, #pids == 1 and "" or "es")

			local ok = os.execute(string.format("taskkill /f /im %s >nul 2>&1", utils.escape_path(img)))

			if ok == true or ok == 0 then
				killed = killed + #pids
			else
				utils.errorf("failed to kill \"\x1b[36m%s\x1b[0m\"", img)
			end
		end

		if killed > 0 then
			utils.successf("killed %d process%s", killed, killed == 1 and "" or "es")
		end
	end
end

return _M
