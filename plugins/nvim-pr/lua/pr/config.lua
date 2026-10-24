local M = {}

-- Defaults are deliberately small: nothing is bundled except the CLIs the user
-- already authenticated, so the only real choice is which picker to use and
-- where self-hosted instances live.
M.defaults = {
	-- nil = detect the provider from `git remote get-url origin`.
	default_provider = nil,

	-- nil = resolve the target branch: remote HEAD, then main, then master.
	-- Set it to pin every `:PR create` to the same base branch.
	default_base = nil,

	ui = {
		-- "fzf-lua" | "vim.ui". Anything that is not fzf-lua falls back to
		-- vim.ui.select, and so does a missing/broken fzf-lua.
		picker = "fzf-lua",
	},

	providers = {
		github = {
			enabled = true,
			hosts = { "github.com" },
		},
		gitlab = {
			enabled = true,
			hosts = { "gitlab.com" },
		},
		azure = {
			enabled = true,
			hosts = { "dev.azure.com", "visualstudio.com" },
		},
	},

	-- action name -> lhs: create, list, view, checkout, open, merge.
	-- Example: mappings = { list = "<leader>pl" }.
	mappings = {},
}

local options = nil

local function merge(base, override)
	if override == nil then
		return vim.deepcopy(base)
	end
	return vim.tbl_deep_extend("force", vim.deepcopy(base), override)
end

--- Merge `opts` into the defaults and remember the result.
---@param opts table|nil
function M.setup(opts)
	options = merge(M.defaults, opts)
	return options
end

--- Current options, building the defaults lazily so `:PR` works without setup().
---@return table
function M.get()
	if not options then
		options = merge(M.defaults, nil)
	end
	return options
end

return M
