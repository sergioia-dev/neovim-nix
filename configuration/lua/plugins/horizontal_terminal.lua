local M = {}

-- Track the horizontal terminal buffer and window
local hterm_buf = nil
local hterm_win = nil

-- Toggle a horizontal terminal at the bottom of the screen.
-- Simple standalone toggle: does not close DBUI/netrw and is independent
-- of the vertical terminal toggle in plugins/terminal.lua.
function M.toggle_bottom_terminal()
	-- If the window exists and is valid, close it (Toggle Off)
	if hterm_win and vim.api.nvim_win_is_valid(hterm_win) then
		vim.api.nvim_win_close(hterm_win, true)
		hterm_win = nil
		return
	end

	-- Calculate 25% of the total screen rows
	local height = math.floor(vim.o.lines * 0.25)

	-- Open a new horizontal split at the bottom
	vim.cmd("botright " .. height .. "split")
	hterm_win = vim.api.nvim_get_current_win()

	-- If a terminal buffer already exists and is valid, reuse it
	if hterm_buf and vim.api.nvim_buf_is_valid(hterm_buf) then
		vim.api.nvim_win_set_buf(0, hterm_buf)
	else
		-- Otherwise, open a new terminal and save its buffer ID
		vim.cmd("terminal")
		hterm_buf = vim.api.nvim_get_current_buf()
	end

	-- Start in insert mode automatically
	vim.cmd("startinsert")
end

return M