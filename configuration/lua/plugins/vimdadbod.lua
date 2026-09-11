-- vim-dadbod UI configuration
-- Read database connection info from DATABASE_URL and DATABASE_NAME
-- environment variables (not DBUI_URL/DBUI_NAME as requested)
vim.g.db_ui_use_nerdtree_to_toggle = 1
vim.g.db_ui_win_position = "right"

-- Environment variables for database connections
vim.g.db_ui_env_variable_url = "_URL"
vim.g.db_ui_env_variable_name = "_NAME"
vim.g.db_ui_dotenv_variable_prefix = "DATABASE"
-- Path to your shared connections file
local connections_file = vim.fn.expand("~/.local/nvim/db_connections/connections.json")

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
