local prev_input = ""
local prev_was_empty = true

local function on_beginedit()
	local exit_code = os.geterrorlevel()

	-- no command was run
	if prev_was_empty then
		return
	end

	-- ignore success and ctrl+c
	if exit_code == 0 or exit_code == 130 then
		return
	end

	-- do not break buffered input
	if console.checkinput(0) then
		return
	end

	local col = console.getcursorpos()

	if col > 1 then
		clink.print("")
	end

	clink.print(string.format("\x1b[31m!! \x1b[90mexit \x1b[31m%d\x1b[0m", exit_code))
end

local function on_endedit(input)
	prev_input = input or ""

	prev_was_empty = (prev_input:match("^%s*$") ~= nil)
end

clink.onbeginedit(on_beginedit)
clink.onendedit(on_endedit)
