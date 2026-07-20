local utils = require("utils")

local _M = {}

local SignalActions = {
	[0] = {
		checkOnly = true,
	},

	[9] = {
		taskkillArguments = "/f /im",
		actionVerb = "killing",
		resultVerb = "killed",
	},

	[15] = {
		taskkillArguments = "/im",
		actionVerb = "terminating",
		resultVerb = "terminated",
	},
}

local KnownSignalNames = utils.create_map({
	"HUP", "INT", "QUIT", "ILL", "TRAP", "ABRT", "IOT", "BUS", "FPE", "KILL",
	"USR1", "SEGV", "USR2", "PIPE", "ALRM", "TERM", "STKFLT", "CHLD", "CLD",
	"CONT", "STOP", "TSTP", "TTIN", "TTOU", "URG", "XCPU", "XFSZ", "VTALRM",
	"PROF", "WINCH", "IO", "POLL", "PWR", "SYS", "UNUSED", "RTMIN", "RTMAX",
})

local function resolveSignal(signalValue)
	local normalized = signalValue:upper()

	if normalized:sub(1, 3) == "SIG" then
		normalized = normalized:sub(4)
	end

	if normalized:match("^%d+$") then
		local number = tonumber(normalized)
		local action = SignalActions[number]

		if action then
			return action
		end

		if number >= 0 and number <= 64 then
			return false, string.format("signal \"%s\" is not supported (use 0, TERM or KILL)", signalValue)
		end

		return false, string.format("unknown signal \"%s\"", signalValue)
	end

	if normalized == "KILL" then
		return SignalActions[9]
	end

	if normalized == "TERM" then
		return SignalActions[15]
	end

	if KnownSignalNames[normalized] then
		return false, string.format("signal \"%s\" is not supported (use 0, TERM or KILL)", signalValue)
	end

	return false, string.format("unknown signal \"%s\"", signalValue)
end

local function parseArguments(args)
	local tokens = utils.split_args(args)

	local names = {}
	local action = SignalActions[15]

	local parseOptions = true

	for index, token in ipairs(tokens) do
		if parseOptions and token == "--" then
			parseOptions = false
		elseif parseOptions and (token == "--signal" or token == "-s") then
			local signalValue = tokens[index + 1]

			if not signalValue then
				return false, string.format("option \"%s\" requires a signal", token)
			end

			local selectedSignal, signalError = resolveSignal(signalValue)

			if not selectedSignal then
				return false, signalError
			end

			action = selectedSignal
			tokens[index + 1] = nil
		elseif parseOptions then
			local inlineSignal = token:match("^%-%-signal=(.*)$")

			if inlineSignal ~= nil then
				local selectedSignal, signalError = resolveSignal(inlineSignal)

				if not selectedSignal then
					return false, signalError
				end

				action = selectedSignal
			elseif token:sub(1, 2) == "--" then
				return false, string.format("unknown option \"%s\"", token)
			elseif token:sub(1, 1) == "-" then
				if token == "-" then
					return false, "unknown option \"-\""
				end

				local selected, err = resolveSignal(token:sub(2))

				if not selected then
					return false, err
				end

				action = selected
			else
				table.insert(names, token)
			end
		else
			table.insert(names, token)
		end
	end

	return {
		names = names,
		signalAction = action,
	}, false
end

function _M.register_command(commands)
	commands["pkill"] = function(args)
		if not args or args == "" then
			utils.errorf("usage: pkill [-signal] <name> [name...]")

			return
		end

		local parsedArguments, parseError = parseArguments(args)

		if not parsedArguments then
			utils.errorf("%s", parseError)

			return
		end

		local wanted = {}

		for _, name in ipairs(parsedArguments.names) do
			local base = utils.trim(name):gsub("%.[eE][xX][eE]$", ""):lower()

			if base ~= "" then
				wanted[base] = true
			end
		end

		if not next(wanted) then
			utils.errorf("usage: pkill [-signal] <name> [name...]")

			return
		end

		local handle = io.popen("tasklist /fo csv /nh 2>nul")

		if not handle then
			utils.errorf("failed to list processes")

			return
		end

		local byImage = {}
		local order = {}

		for line in handle:lines() do
			local image, pid = line:match('^"([^"]+)","(%d+)"')

			if image and pid then
				local imageLower = image:lower()
				local imageBase = imageLower:gsub("%.exe$", "")

				if wanted[imageBase] then
					if not byImage[image] then
						byImage[image] = {}

						table.insert(order, image)
					end

					table.insert(byImage[image], pid)
				end
			end
		end

		handle:close()

		if #order == 0 then
			utils.errorf("no matching process found")

			return
		end

		local signalAction = parsedArguments.signalAction

		if signalAction.checkOnly then
			local matched = 0

			for _, image in ipairs(order) do
				matched = matched + #byImage[image]
			end

			utils.successf("found %d matching process%s", matched, matched == 1 and "" or "es")

			return
		end

		local terminated = 0

		for _, image in ipairs(order) do
			local pids = byImage[image]

			utils.printf(
				"%s \"\x1b[36m%s\x1b[0m\" (%d process%s)",
				signalAction.actionVerb,
				image,
				#pids,
				#pids == 1 and "" or "es"
			)

			local command = string.format(
				"taskkill %s %s >nul 2>&1",
				signalAction.taskkillArguments,
				utils.escape_path(image)
			)

			local ok = os.execute(command)

			if ok == true or ok == 0 then
				terminated = terminated + #pids
			else
				utils.errorf(
					"failed to %s \"\x1b[36m%s\x1b[0m\"",
					signalAction.actionVerb:gsub("ing$", ""),
					image
				)
			end
		end

		if terminated > 0 then
			utils.successf(
				"%s %d process%s",
				signalAction.resultVerb,
				terminated,
				terminated == 1 and "" or "es"
			)
		end
	end
end

return _M
