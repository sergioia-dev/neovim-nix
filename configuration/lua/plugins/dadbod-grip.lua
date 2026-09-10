require("dadbod-grip").setup({
	limit = 100,
	max_col_width = 40,
	timeout = 10000,
	completion = false, -- Use nvim-cmp source (dadbod_grip) instead of built-in
	connections_path = nil,
	picker = "telescope",
	border = "rounded",
	cell_split = "horizontal",
	sticky_header = true,
	open_sidebar = true,
})
