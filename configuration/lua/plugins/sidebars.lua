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

-- Return the window ID if the netrw explorer is visible in any window.
local function get_explorer_window()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.bo[buf].filetype == "netrw" then
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

-- Close any other sidebar (DBUI, netrw, or vertical terminal) so only one sidebar is visible at a time.
-- Safe to call from other modules; does nothing if no other sidebar is open.
function M.close_other_sidebars()
	focus_non_terminal_window()

	if dadbod_open then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	local explorer_win = get_explorer_window()
	if explorer_win then
		vim.api.nvim_win_close(explorer_win, true)
	end

	-- Close the vertical terminal too, so only one sidebar is visible at a time
	require("plugins.terminal").close_terminal()
end
-- Close the horizontal terminal too, so only one sidebar is visible at a time
	require("plugins.horizontal_terminal").close_terminal()

-- Called by <leader>fm. Closes DadBod first, then toggles the default file explorer using :Lexplore!.
function M.lexplore()
	focus_non_terminal_window()
	require("plugins.terminal").close_terminal()
require("plugins.horizontal_terminal").close_terminal()
	-- Close DB sidebar first so only the explorer remains
	if dadbod_open then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	local explorer_win = get_explorer_window()
	if explorer_win then
		vim.api.nvim_win_close(explorer_win, true)
	else
		vim.cmd("Lexplore!")
	end
end

-- Called by <F1>. Toggles vim-dadbod UI only if database clients are available.
-- Closes the explorer if it is open in any window, so only one database sidebar is visible at a time.
function M.toggle_dadbod()
	focus_non_terminal_window()
	require("plugins.terminal").close_terminal()
require("plugins.horizontal_terminal").close_terminal()
	local explorer_win = get_explorer_window()
	if explorer_win then
		vim.api.nvim_win_close(explorer_win, true)
	end

	if dadbod_open then
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