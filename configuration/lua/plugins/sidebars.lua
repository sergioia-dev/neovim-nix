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

-- Track which sidebar is currently open (mutually exclusive)
local dadbod_open = false

local minifiles_toggle = require("plugins.mini-files").minifiles_toggle
M.minifiles_toggle = minifiles_toggle

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

-- Check if DadBod UI is currently open by detecting the actual window.
-- This is more reliable than the dadbod_open flag which can get out of sync.
function M.is_dadbod_open()
	return get_dadbod_window() ~= nil
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

-- Close any other sidebar (DBUI, terminal, or mini.files) so only one sidebar is visible at a time.
-- Safe to call from other modules; does nothing if no other sidebar is open.
function M.close_other_sidebars()
	focus_non_terminal_window()

	if M.is_dadbod_open() then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	minifiles_toggle()

	-- Close the terminal too, so only one sidebar is visible at a time
	require("plugins.terminal").close_terminal()
end

-- Called by <leader>fm. Closes DadBod first, then toggles the default file explorer (mini.files).
function M.lexplore()
	focus_non_terminal_window()
	require("plugins.terminal").close_terminal()
	-- Close DB sidebar first so only the explorer remains
	if M.is_dadbod_open() then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	minifiles_toggle()
end

-- Called by <F1>. Toggles vim-dadbod UI only if database clients are available.
-- Closes mini.files if it is open, so only one database sidebar is visible at a time.
function M.toggle_dadbod()
	focus_non_terminal_window()
	require("plugins.terminal").close_terminal()
	minifiles_toggle()

	if M.is_dadbod_open() then
		vim.cmd("DBUIToggle")
		dadbod_open = false
		return
	end

	if not check_dadbod_clients() then
		notify_no_client(DADBOD_CLIENTS)
		return
	end

	vim.cmd("DBUIToggle")
	dadbod_open = true
end

return M
