local fzf = require("fzf-lua")
fzf.setup({
	keymap = {
		builtin = {
			-- Scroll the builtin previewer with Ctrl+d / Ctrl+u
			["<C-f>"] = "preview-page-down",
			["<C-b>"] = "preview-page-up",
		},
		fzf = {
			-- Scroll the fzf native previewer with Ctrl+f / Ctrl+b
			["ctrl-f"] = "preview-page-down",
			["ctrl-b"] = "preview-page-up",
		},
	},
})
