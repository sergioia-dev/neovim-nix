local M = {}

-- Track whether the horizontal terminal sidebar is currently open (mutually exclusive)
local hterminal_open = false

-- Cache the horizontal terminal buffer so the same session can be reused across toggles
local hterm_buf = nil

-- Return the window ID if a horizontal terminal window is visible in any window.
-- A horizontal terminal is identified by buftype == "terminal" and a window height
-- of 25% or less of the screen (distinguishing it from the vertical terminal).
local function get_horizontal_terminal_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "terminal" then
			local height = vim.api.nvim_win_get_height(win)
			if height <= math.floor(vim.o.lines * 0.25) then
				return win
			end
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

-- Close the horizontal terminal window if one is visible. Safe to call from other modules.
function M.close_terminal()
	local term_win = get_horizontal_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		hterminal_open = false
	end
end

-- Called by <leader>fh. Toggles a 25% bottom horizontal terminal.
-- Closes any other sidebar (DBUI / netrw / vertical terminal) first so only one sidebar is visible at a time.
function M.toggle_bottom_terminal()
	-- If a horizontal terminal window is already visible, close it (Toggle Off)
	local term_win = get_horizontal_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		hterminal_open = false
		return
	end

	-- Close any other sidebar so the horizontal terminal is the only sidebar
	require("plugins.sidebars").close_other_sidebars()

	-- Calculate 25% of the total screen rows
	local height = math.floor(vim.o.lines * 0.25)

	-- Open a new horizontal split at the bottom
	vim.cmd("botright " .. height .. "split")

	-- If a horizontal terminal buffer already exists and is valid, reuse it
	if hterm_buf and vim.api.nvim_buf_is_valid(hterm_buf) then
		vim.api.nvim_win_set_buf(0, hterm_buf)
	else
		-- Otherwise, open a new terminal and save its buffer ID
		vim.cmd("terminal")
		hterm_buf = vim.api.nvim_get_current_buf()
	end

	-- Start in insert mode automatically
	vim.cmd("startinsert")

	hterminal_open = true
end

return M