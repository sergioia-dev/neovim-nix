local M = {}

function M.setup()
	-- Load all configuration parts
	require("plugins.gitsigns")
	require("plugins.luasnip")
	require("plugins.render-markdown")
	require("plugins.net_picker")
	require("plugins.kulala")
	require("plugins.lualine")
	require("plugins.noice")
	require("plugins.notify")
	require("plugins.neogit")
	require("plugins.smear-cursor")
	require("plugins.auto-pairs")
	require("plugins.lspsaga")
	require("plugins.mini-files")
	require("plugins.todo-comments")
	require("plugins.vimdadbod")
	require("plugins.pi")
	require("plugins.cmp")
	require("plugins.toggable-term")
	require("plugins.taskwarrior")
	require("plugins.marks")
	require("plugins.fzf")
	require("plugins.nvim-pr")
end

M.setup()
return M
