-- Syntax highlighting for project-tree-nvim
-- Highlights directories, files, permissions, sizes, and tree connectors.

local M = {}

-- Define highlight groups with colors that match common Neovim colorschemes.
-- These can be overridden by the user's colorscheme after setup.
M.highlights = {
	TreeDir = { fg = "#6c8ebf", bg = "#2e3440" },
	TreeFile = { fg = "#d8dee9", bg = "#2e3440" },
	TreeSize = { fg = "#81a1c1", bg = "#2e3440" },
	TreePerm = { fg = "#bf6b6b", bg = "#2e3440" },
	TreeConnector = { fg = "#a3be8c", bg = "#2e3440" },
}

-- Apply highlights to every line in the buffer.
-- The buffer must be modifiable when calling this function.
function M.apply_highlights(bufnr, lines)
	vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

	for line_idx, line in ipairs(lines) do
		local row = line_idx - 1 -- nvim_buf_add_highlight uses 0-indexed rows

		-- Highlight permission string at the start of the line
		local perm_start, perm_end = line:find "^[-rwx]+"
		if perm_start then
			vim.api.nvim_buf_add_highlight(bufnr, -1, "TreePerm", row, perm_start - 1, perm_end)
		end

		-- Highlight tree connector at the start of the line
		local conn_start, conn_end = line:find "^[│├└┌]"
		if conn_start then
			vim.api.nvim_buf_add_highlight(bufnr, -1, "TreeConnector", row, conn_start - 1, conn_end)
		end

		-- Highlight directory names (after connector, until size or filename)
		-- Pattern: connector followed by spaces and a name that does NOT contain a size token
		local name_start, name_end = line:find "[│├└┌]+%s+[%a_][%w_%.-]*"
		if not name_start then
			-- Try without connector for lines that are just filenames
			name_start, name_end = line:find "[%a_][%w_%.-]+$"
		end
		if name_start then
			-- Determine if this is a directory by checking for trailing / or known dir patterns
			local after_name = line:sub(name_end + 1, name_end + 2)
			if after_name == "/" or line:match "^[│├└┌]+%s+" then
				vim.api.nvim_buf_add_highlight(bufnr, -1, "TreeDir", row, name_start - 1, name_end)
			else
				vim.api.nvim_buf_add_highlight(bufnr, -1, "TreeFile", row, name_start - 1, name_end)
			end
		end

		-- Highlight file extension if present in the filename portion
		local file_part = line:match "([%a_][%w_%.-]+%.[%a_][%w_%.]*%s*$)"
		if file_part then
			local ext_start = #line - #file_part + 1
			local _, ext_end = file_part:find "%.[%a_][%w_%.]*$"
			if ext_end then
				local abs_ext_start = ext_start + ext_end - 1
				vim.api.nvim_buf_add_highlight(bufnr, -1, "TreeFile", row, abs_ext_start - 1, abs_ext_end)
			end
		end

		-- Highlight size token if present
		local size_start, size_end = line:find "%b[0-9]+[KMG]?B"
		if size_start then
			vim.api.nvim_buf_add_highlight(bufnr, -1, "TreeSize", row, size_start - 1, size_end)
		end
	end

	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

return M