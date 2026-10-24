local M = {}

--- Host part of a git remote URL, lowercased.
--- Handles `git@host:owner/repo.git`, `ssh://git@host:22/owner/repo.git`
--- and `https://host/owner/repo.git`.
---@param url string|nil
---@return string|nil
function M.host(url)
	url = vim.trim(url or "")
	if url == "" then
		return nil
	end
	-- Drop the scheme, then any userinfo (`git@`, `oauth2:token@`, ...).
	local rest = url:gsub("^%a[%w+.-]*://", "")
	rest = rest:gsub("^[^/@]*@", "")
	local host = rest:match("^([%w._-]+)")
	if not host then
		return nil
	end
	return host:lower()
end

--- Parse an Azure DevOps remote into its organization/project/repository.
--- Supports:
---   https://dev.azure.com/<org>/<project>/_git/<repo>
---   git@ssh.dev.azure.com:v3/<org>/<project>/<repo>
---   https://<org>.visualstudio.com[/DefaultCollection]/<project>/_git/<repo>
---@param url string|nil
---@return table|nil context { organization, project, repository }
function M.azure_context(url)
	url = vim.trim(url or "")
	if url == "" then
		return nil
	end

	local organization, project, repository = url:match("dev%.azure%.com[:/]([^/]+)/([^/]+)/_git/([^/?#]+)")
	if not organization then
		organization, project, repository = url:match("ssh%.dev%.azure%.com[:/]v3/([^/]+)/([^/]+)/([^/?#]+)")
	end
	if not organization then
		local suffix = url:match("([%w._-]+)%.visualstudio%.com[:/](.+)$")
		if suffix then
			organization = suffix
			local rest = url:match("%.visualstudio%.com[:/](.+)$")
			project, repository = rest:match("^DefaultCollection/([^/]+)/_git/([^/?#]+)")
			if not project then
				project, repository = rest:match("^([^/]+)/_git/([^/?#]+)")
			end
		end
	end

	if not organization or not project then
		return nil
	end
	return {
		organization = organization,
		project = project,
		repository = (repository or ""):gsub("%.git$", ""),
	}
end

local root_cache

local function git_root(dir)
	local out = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
	if vim.v.shell_error ~= 0 or not out[1] then
		return nil
	end
	return vim.trim(out[1])
end

--- Repository the commands act on: the root of the working directory, falling
--- back to the root of the current buffer's file.
---@return string|nil
function M.root()
	if root_cache ~= nil then
		return root_cache or nil
	end

	root_cache = git_root(vim.fn.getcwd())
	if not root_cache then
		local name = vim.api.nvim_buf_get_name(0)
		if name ~= "" then
			root_cache = git_root(vim.fs.dirname(name))
		end
	end

	root_cache = root_cache or false
	return root_cache or nil
end

--- Drop the memoised repository root, e.g. after `:cd` or a new worktree.
function M.reset()
	root_cache = nil
end

--- Raw output of `git remote get-url origin`, or nil outside a git repo.
---@return string|nil
function M.remote_url()
	local root = M.root()
	local cmd = { "git" }
	if root then
		vim.list_extend(cmd, { "-C", root })
	end
	vim.list_extend(cmd, { "remote", "get-url", "origin" })

	local out = vim.fn.systemlist(cmd)
	if vim.v.shell_error ~= 0 or not out[1] then
		return nil
	end
	return vim.trim(out[1])
end

--- Provider name for a remote URL (defaults to the origin remote).
---@param url string|nil
---@return string|nil name
---@return string|nil host
function M.name(url, opts)
	local cfg = opts or require("pr.config").get()
	local host = M.host(url or M.remote_url())
	if not host then
		return nil, nil
	end

	-- Iterate in a stable order so a host listed twice resolves deterministically.
	for _, name in ipairs({ "github", "gitlab", "azure" }) do
		local provider = (cfg.providers or {})[name]
		if provider and provider.enabled ~= false then
			for _, known in ipairs(provider.hosts or {}) do
				if host == known or host:match("%." .. vim.pesc(known) .. "$") then
					return name, host
				end
			end
		end
	end
	return nil, host
end

return M
