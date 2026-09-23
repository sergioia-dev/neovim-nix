local M = {}

-- Supported database clients for vim-dadbod
local DADBOD_CLIENTS = {
	"bigquery",
	"clickhouse",
	"duckdb",
	"impala",
	"mongo",
	"mysql",
	"mariadb",
	"oracle",
	"osquery",
	"psql",
	"presto",
	"redis",
	"snowflake",
	"sqlcmd",
	"sqlite3",
}

-- Cache for client availability (set once on module load)
local dadbod_client_available = nil

local mini_files = require("plugins.mini-files")
local minifiles_toggle = mini_files.minifiles_toggle
local minifiles_close = mini_files.minifiles_close
local minifiles_is_open = mini_files.minifiles_is_open

local function check_dadbod_clients()
	if dadbod_client_available ~= nil then
		return dadbod_client_available
	end
	for _, client in ipairs(DADBOD_CLIENTS) do
		if vim.fn.executable(client) == 1 then
			dadbod_client_available = true
			return true
		end
	end
	dadbod_client_available = false
	return false
end

local function notify_no_client(clients)
	vim.notify(
		"No supported database client available. Install one of: " .. table.concat(clients, ", "),
		vim.log.levels.WARN
	)
end

-- Return the window ID if the DadBod UI is visible in any window.
-- DadBod UI buffers have filetype 'dbui'.
local function get_dadbod_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "dbui" then
			return win
		end
	end
	return nil
end

-- Return true when the DadBod UI is visible in any window.
local function is_dadbod_open()
	return get_dadbod_window() ~= nil
end

-- Switch to a non-terminal, non-floating window so a sidebar splits relative to a
-- real file buffer instead of opening over a terminal or over mini.files' float.
-- Does nothing when no such window exists.
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

-- Close any other sidebar (DBUI, terminal, or mini.files) so only one sidebar is visible at a time.
-- Safe to call from other modules; does nothing if no other sidebar is open.
function M.close_other_sidebars()
	focus_non_terminal_window()

	if is_dadbod_open() then
		vim.cmd("DBUIToggle")
	end

	minifiles_close()

	-- Close the terminal too, so only one sidebar is visible at a time
	require("plugins.terminal").close_terminal()
end

-- Called by <leader>fm. Toggles the mini.files explorer, following the same
-- workflow as the DBUI (<F1>) and terminal (<leader>tv / <leader>th) sidebars:
-- if mini.files is already open, close it; otherwise close every other sidebar
-- first and then open it, so exactly one sidebar is ever visible.
function M.toggle_minifiles()
	focus_non_terminal_window()

	-- Toggle off: mini.files is already the visible sidebar
	if minifiles_is_open() then
		minifiles_close()
		return
	end

	-- Toggle on: close DBUI / terminals first, then open the explorer
	M.close_other_sidebars()

	minifiles_toggle()
end

-- Called by <F1>. Toggles vim-dadbod UI only if database clients are available.
-- Closes mini.files if it is open, so only one database sidebar is visible at a time.
function M.toggle_dadbod()
	focus_non_terminal_window()
	require("plugins.terminal").close_terminal()

	if is_dadbod_open() then
		vim.cmd("DBUIToggle")
		return
	end

	if not check_dadbod_clients() then
		notify_no_client(DADBOD_CLIENTS)
		return
	end

	-- Close mini.files only now (never open it) so DBUI is the only sidebar
	minifiles_close()

	vim.cmd("DBUIToggle")
end

return M
