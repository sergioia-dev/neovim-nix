vim.g.netrw_liststyle = 3
vim.g.netrw_banner = 0
vim.g.netrw_browse_split = 4
vim.g.netrw_winsize = 20

-- Intercept '%' to create a file, open it in the main area, and wipe out Netrw
vim.api.nvim_create_autocmd("FileType", {
	pattern = "netrw",
	callback = function()
		vim.keymap.set("n", "%", function()
			-- 1. Ask you for the file name
			local filename = vim.fn.input("Create file: ")
			if filename == "" then
				return
			end

			-- 2. Get Netrw's current directory path and the netrw buffer number
			local dir = vim.b.netrw_curdir or vim.fn.getcwd()
			local filepath = dir .. "/" .. filename
			local netrw_buf = vim.api.nvim_get_current_buf()

			-- 3. Jump to the previous window (your main code area)
			vim.cmd("wincmd p")

			-- 4. Open and save the new file
			vim.cmd("edit " .. vim.fn.fnameescape(filepath))
			vim.cmd("write")

			-- 5. Forcefully wipe out the Netrw buffer (this closes its window instantly)
			vim.api.nvim_buf_delete(netrw_buf, { force = true })
		end, { buffer = true, silent = true })
	end,
})
