vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Create an autocmd to automatically set the target window when entering netrw
vim.api.nvim_create_autocmd("WinEnter", {
	pattern = "*",
	callback = function()
		if vim.bo.filetype == "netrw" then
			-- 'C' tells netrw to use the *previous* window as the target for new files
			vim.cmd("normal! C")
		end
	end,
})
