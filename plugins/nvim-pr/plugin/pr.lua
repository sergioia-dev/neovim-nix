local M = {}

local ACTIONS = { "create", "list", "view", "checkout", "open", "merge" }

vim.api.nvim_create_user_command("PR", function(args)
	require("pr").dispatch(args.fargs)
end, {
	nargs = "*",
	desc = "Pull requests: create, list, view, checkout, open or merge",
	complete = function(arglead, cmdline)
		local ok, result = pcall(function()
			return require("pr").complete(arglead, cmdline)
		end)
		return ok and result or {}
	end,
})

-- `:cd` or a new worktree changes which repository the CLIs act on.
vim.api.nvim_create_autocmd("DirChanged", {
	callback = function()
		require("pr.detect").reset()
		require("pr.git").reset()
	end,
	desc = "nvim-pr: re-detect the repository after a directory change",
})

-- Stable entry points: users bind these through `require("pr").setup({ mappings = {} })`
-- or by mapping `<Plug>(pr-list)` themselves.
for _, action in ipairs(ACTIONS) do
	vim.keymap.set("n", ("<Plug>(pr-%s)"):format(action), function()
		require("pr").dispatch({ action })
	end, { desc = ("nvim-pr: %s"):format(action) })
end

return M
