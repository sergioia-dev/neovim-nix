local M = {}

-- Track whether the terminal sidebar is currently open (mutually exclusive)
local terminal_open = false

-- Cache the terminal buffer so the same session can be reused across toggles
local term_buf = nil

-- Return the window ID if a terminal window is visible in any window.
local function get_terminal_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "terminal" then
			return win
		end
	end
	return nil
end

-- Switch to a non-terminal window so a sidebar splits relative to a
-- real file buffer instead of opening over a terminal buffer.
-- Returns true if a non-terminal window was focused, false otherwise.
local function focus_non_terminal_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype ~= "terminal" then
			vim.api.nvim_set_current_win(win)
			return true
		end
	end
	return false
end

-- Close the terminal window if one is visible. Safe to call from other modules.
function M.close_terminal()
	local term_win = get_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		terminal_open = false
	end
end

-- Called by <leader>fg. Toggles a 30% right-side terminal.
-- Closes any other sidebar (DBUI / netrw) first so only one sidebar is visible at a time.
function M.toggle_right_terminal()
	-- If a terminal window is already visible, close it (Toggle Off)
	local term_win = get_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		terminal_open = false
		return
	end

	-- Close any other sidebar (DBUI or netrw) so the terminal is the only sidebar
	require("plugins.sidebars").close_other_sidebars()

	-- Calculate 30% of the total screen columns
	local width = math.floor(vim.o.columns * 0.30)

	-- Open a new vertical split on the far right
	vim.cmd("botright " .. width .. "vsplit")

	-- If a terminal buffer already exists and is valid, reuse it
	if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
		vim.api.nvim_win_set_buf(0, term_buf)
	else
		-- Otherwise, open a new terminal and save its buffer ID
		vim.cmd("terminal")
		term_buf = vim.api.nvim_get_current_buf()
	end

	-- Start in insert mode automatically
	vim.cmd("startinsert")

	terminal_open = true
end

return M