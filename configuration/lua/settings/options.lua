vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.scrolloff = 999
vim.opt.sidescrolloff = 999
vim.opt.expandtab = true
vim.opt.clipboard = "unnamed"

vim.cmd("colorscheme catppuccin-mocha")
vim.defer_fn(function()
	vim.cmd("colorscheme catppuccin-mocha")
end, 5000)

local config = {
	virtual_text = true,
	update_in_insert = true,
	underline = true,
	severity_sort = true,
}

vim.api.nvim_create_autocmd("FileType", {
	pattern = "netrw",
	callback = function()
		-- Disable F1 inside netrw
		vim.keymap.set("n", "<F1>", "<Nop>", { remap = false, buffer = true })
	end,
})

-- -- Automatically enter Insert mode when a terminal opens
-- vim.api.nvim_create_autocmd("TermOpen", {
-- 	group = vim.api.nvim_create_augroup("TerminalSettings", { clear = true }),
-- 	pattern = "*",
-- 	callback = function()
-- 		vim.cmd("startinsert")
-- 	end,
-- })
--
-- Terminal toggle is now configured in configuration/lua/plugins/terminal.lua

vim.diagnostic.config(config)

-- Enable autoread
vim.o.autoread = true
