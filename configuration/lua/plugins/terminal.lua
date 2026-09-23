local M = {}

-- Track whether terminal sidebars are currently open (mutually exclusive)
local vertical_terminal_open = false
local horizontal_terminal_open = false

-- Cache terminal buffers so the same session can be reused across toggles
local vertical_term_buf = nil
local horizontal_term_buf = nil

-- Shared focus function. Skips floating windows too so a split is never anchored
-- to mini.files' floating explorer or another overlay.
local function focus_non_terminal_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local is_float = vim.api.nvim_win_get_config(win).relative ~= ""
		local buf = vim.api.nvim_win_get_buf(win)
		if not is_float and vim.bo[buf].buftype ~= "terminal" then
			vim.api.nvim_set_current_win(win)
			return
		end
	end
end

-- Return the window ID if a vertical terminal window is visible.
-- A vertical terminal is identified by buftype == "terminal" and a window width
-- of 30% or less of the screen (distinguishing it from the horizontal terminal).
local function get_vertical_terminal_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].buftype == "terminal" then
			local width = vim.api.nvim_win_get_width(win)
			if width <= math.floor(vim.o.columns * 0.30) then
				return win
			end
		end
	end
	return nil
end

-- Return the window ID if a horizontal terminal window is visible.
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

-- Close the vertical terminal window if one is visible. Safe to call from other modules.
function M.close_vertical_terminal()
	local term_win = get_vertical_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		vertical_terminal_open = false
	end
end

-- Close the horizontal terminal window if one is visible. Safe to call from other modules.
function M.close_horizontal_terminal()
	local term_win = get_horizontal_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		horizontal_terminal_open = false
	end
end

-- Close both terminal windows if visible. Safe to call from other modules.
function M.close_terminal()
	M.close_vertical_terminal()
	M.close_horizontal_terminal()
end

-- Called by <leader>fg. Toggles a 30% right-side vertical terminal.
-- Closes any other sidebar (DBUI / netrw / horizontal terminal) first so only one sidebar is visible at a time.
function M.toggle_right_terminal()
	focus_non_terminal_window()

	-- If a vertical terminal window is already visible, close it (Toggle Off)
	local term_win = get_vertical_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		vertical_terminal_open = false
		return
	end

	-- Close any other sidebar (DBUI or netrw) so the terminal is the only sidebar
	require("plugins.sidebars").close_other_sidebars()

	-- Close the horizontal terminal too, so only one terminal is visible at a time
	M.close_horizontal_terminal()

	-- Calculate 30% of the total screen columns
	local width = math.floor(vim.o.columns * 0.30)

	-- Open a new vertical split on the far right
	vim.cmd("botright " .. width .. "vsplit")

	-- If a vertical terminal buffer already exists and is valid, reuse it
	if vertical_term_buf and vim.api.nvim_buf_is_valid(vertical_term_buf) then
		vim.api.nvim_win_set_buf(0, vertical_term_buf)
	else
		-- Otherwise, open a new terminal and save its buffer ID
		vim.cmd("terminal")
		vertical_term_buf = vim.api.nvim_get_current_buf()
	end

	-- Start in insert mode automatically
	vim.cmd("startinsert")

	vertical_terminal_open = true
end

-- Called by <leader>fh. Toggles a 25% bottom horizontal terminal.
-- Closes any other sidebar (DBUI / netrw / vertical terminal) first so only one sidebar is visible at a time.
function M.toggle_bottom_terminal()
	focus_non_terminal_window()

	-- If a horizontal terminal window is already visible, close it (Toggle Off)
	local term_win = get_horizontal_terminal_window()
	if term_win then
		vim.api.nvim_win_close(term_win, true)
		horizontal_terminal_open = false
		return
	end

	-- Close any other sidebar so the horizontal terminal is the only sidebar
	require("plugins.sidebars").close_other_sidebars()

	-- Close the vertical terminal too, so only one terminal is visible at a time
	M.close_vertical_terminal()

	-- Calculate 25% of the total screen rows
	local height = math.floor(vim.o.lines * 0.25)

	-- Open a new horizontal split at the bottom
	vim.cmd("botright " .. height .. "split")

	-- If a horizontal terminal buffer already exists and is valid, reuse it
	if horizontal_term_buf and vim.api.nvim_buf_is_valid(horizontal_term_buf) then
		vim.api.nvim_win_set_buf(0, horizontal_term_buf)
	else
		-- Otherwise, open a new terminal and save its buffer ID
		vim.cmd("terminal")
		horizontal_term_buf = vim.api.nvim_get_current_buf()
	end

	-- Start in insert mode automatically
	vim.cmd("startinsert")

	horizontal_terminal_open = true
end

return M