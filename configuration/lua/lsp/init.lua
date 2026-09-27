local M = {}

function M.setup()
	-- Load all configuration parts
	require("lsp.typescript")
	require("lsp.lua")
	require("lsp.nix")
	require("lsp.java")
	require("lsp.dart")
	require("lsp.bash")
	require("lsp.css")
	require("lsp.json")
	require("lsp.html")
	require("lsp.formatting")
	require("lsp.linting")
end

M.setup()

return M
