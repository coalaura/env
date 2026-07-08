local whitelist = {
    "cd", "pushd", "popd", "dirs", "clear", "cls", "..", "...", "home"
}

local prev_prompt_line = nil
local prev_input = ""
local prev_was_empty = true

local function is_whitelisted(cmd)
    local first_word = cmd:match("^%s*(%S+)") or ""

    first_word = first_word:lower()

    for _, w in ipairs(whitelist) do
        if first_word == w:lower() then
            return true
        end
    end

    return false
end

local function save_cursor_row()
	local _, row = console.getcursorpos()

	prev_prompt_line = row
end

local function on_beginedit()
    local exit_code = os.geterrorlevel()

    -- no command was run
    if prev_was_empty then
        save_cursor_row()

        return
    end

    -- skip ctrl+c (SIGINT = exit 130)
    if exit_code == 130 then
        save_cursor_row()

        return
    end

    -- skip whitelist
    if is_whitelisted(prev_input) then
        save_cursor_row()

        return
    end

    -- skip if buffered input
    if console.checkinput(0) then
        save_cursor_row()

        return
    end

    -- cursor pos
    local col, row = console.getcursorpos()

    local no_output = false

    if prev_prompt_line then
        local expected = prev_prompt_line + 1

        if row == expected and col == 1 then
            no_output = true
        end
    end

    if no_output then
        if exit_code == 0 then
            clink.print("\x1b[90m# no-output \x1b[32m<0>\x1b[0m")
        else
            clink.print(string.format("\x1b[90m# no-output \x1b[31m<%d>\x1b[0m", exit_code))
        end

        save_cursor_row()
    else
        prev_prompt_line = row
    end
end

local function on_endedit(input)
    prev_input = input or ""

    prev_was_empty = (prev_input:match("^%s*$") ~= nil)
end

clink.onbeginedit(on_beginedit)
clink.onendedit(on_endedit)
