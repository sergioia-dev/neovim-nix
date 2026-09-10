local M = {}

-- Supported database clients for dadbod-grip
local GRIP_CLIENTS = {
	"psql", -- PostgreSQL
	"mysql", -- MySQL / MariaDB
	"sqlite3", -- SQLite
	"duckdb", -- DuckDB
	"sqlcmd", -- SQL Server
}

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
local grip_client_available = nil
local dadbod_client_available = nil

-- Track which sidebar is currently open (mutually exclusive)
local datagrip_open = false
local dadbod_open = false

local function check_grip_clients()
	if grip_client_available ~= nil then
		return grip_client_available
	end
	for _, client in ipairs(GRIP_CLIENTS) do
		if vim.fn.executable(client) == 1 then
			grip_client_available = true
			return true
		end
	end
	grip_client_available = false
	return false
end

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

local function is_nvim_tree_open()
	local ok, api = pcall(require, "nvim-tree.api")
	if not ok then
		return false
	end
	return api.tree.is_visible() == true
end

-- Called by <leader>fm.
function M.toggle_explorer()
	if is_nvim_tree_open() then
		vim.cmd("NvimTreeClose")
	else
		vim.cmd("NvimTreeToggle")
	end
end

-- Called by <F1>. Toggles dadbod-grip only if database clients are available.
-- Closes dadbod if it is open, so only one database sidebar is visible at a time.
function M.toggle_datagrip()
	if is_nvim_tree_open() then
		vim.cmd("NvimTreeClose")
	end

	-- If dadbod is open, close it first so only datagrip remains
	if dadbod_open then
		vim.cmd("DBUIToggle")
		dadbod_open = false
	end

	if datagrip_open then
		vim.cmd("GripToggle")
		datagrip_open = false
		return
	end

	if not check_grip_clients() then
		notify_no_client(GRIP_CLIENTS)
		return
	end

	vim.cmd("GripToggle")
	datagrip_open = true
end

-- Called by <F2>. Toggles vim-dadbod UI only if database clients are available.
-- Closes datagrip if it is open, so only one database sidebar is visible at a time.
function M.toggle_dadbod()
	if is_nvim_tree_open() then
		vim.cmd("NvimTreeClose")
	end

	-- If datagrip is open, close it first so only dadbod remains
	if datagrip_open then
		vim.cmd("GripToggle")
		datagrip_open = false
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