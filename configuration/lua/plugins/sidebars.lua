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

local function is_explorer_open()
	return vim.bo.filetype == "netrw"
end

-- Called by <leader>fm. Closes DadBod first, then toggles the default file explorer using :Lexplore!.
function M.lexplore()
	-- Close DB sidebar first so only the explorer remains
	if dadbod_open then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	if is_explorer_open() then
		vim.cmd("close")
	else
		vim.cmd("Lexplore!")
	end
end

-- Called by <F2>. Toggles vim-dadbod UI only if database clients are available.
-- Closes the explorer if it is open, so only one database sidebar is visible at a time.
function M.toggle_dadbod()
	if is_explorer_open() then
		vim.cmd("close")
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