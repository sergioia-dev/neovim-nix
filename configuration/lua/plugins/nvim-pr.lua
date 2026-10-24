-- Pull requests (:PR). The provider is detected from `origin`, so the same
-- commands work in a GitHub, GitLab and Azure DevOps checkout; `gh`, `glab` and
-- `az` are only ever called, never configured, so whatever `gh auth login`
-- already set up is what gets used. Run `:checkhealth pr` to see what is found.
require("pr").setup({
	-- Override detection when `origin` is a mirror or a fork remote, e.g.
	-- default_provider = "gitlab",

	ui = {
		-- "fzf-lua" uses the picker this config already loads; anything else
		-- falls back to vim.ui.select.
		picker = "fzf-lua",
	},

	providers = {
		github = { enabled = true },
		gitlab = { enabled = true },
		azure = { enabled = true },
	},

	-- No defaults on purpose: bind whatever fits the rest of the leader map,
	-- e.g. list = "<leader>gl", create = "<leader>gc".
	mappings = {},
})
