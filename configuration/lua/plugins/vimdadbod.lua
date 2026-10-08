-- vim-dadbod UI configuration
vim.g.db_ui_use_nerdtree_to_toggle = 1
vim.g.db_ui_win_position = "right"

-- Path to your shared connections file
local connections_file = vim.fn.expand("~/.local/share/nvim-custom/db/connections.json")

-- Read the file and decode JSON
local file = io.open(connections_file, "r")
if file then
	local content = file:read("*a")
	file:close()

	-- Decode JSON into a Lua table
	local ok, connections = pcall(vim.json.decode, content)

	if ok then
		-- Assign to vim.g.dbs
		vim.g.dbs = connections
	else
		vim.notify("Failed to parse connections.json: " .. tostring(connections), vim.log.levels.ERROR)
	end
else
	vim.notify("Connections file not found: " .. connections_file, vim.log.levels.WARN)
end

-- These connections are database servers, not single databases: vim-dadbod-manager
-- renders each of them as a server node and lists the databases behind it as
-- children of that node. The names must match the "name" fields in
-- connections.json, and the scheme must support database discovery
-- (sqlserver, mysql, mariadb, postgresql, ... -- see the plugin README).
vim.g.dbui_multidb_masters = {
	"Banco Production",
	"Rama Production Dev",
	"Rama Production QA",
	"Banco Local SQLServer",
	"Rama Local MySQL",
}
