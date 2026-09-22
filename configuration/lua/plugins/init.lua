local M = {}

function M.setup()
	-- Load all configuration parts
	require("plugins.gitsigns")
	require("plugins.luasnip")
	require("plugins.telescope")
	require("plugins.kulala")
	require("plugins.lualine")
	require("plugins.noice")
	require("plugins.notify")
	require("plugins.smear-cursor")
	require("plugins.auto-pairs")
	require("plugins.lspsaga")
	require("plugins.nvim-tree")
	require("plugins.todo-comments")
	require("plugins.vimdadbod")
	require("plugins.pi")
	require("plugins.terminal")
	require("plugins.marks")
	require("plugins.base64")
end

M.setup()
return M
