local base = require("pr.providers.base")
local detect = require("pr.detect")

local M = {
	name = "azure",
	cli = "az",
}

function M.is_available()
	return vim.fn.executable(M.cli) == 1
end

--- Organization/project/repository for the current repo, from the git remote.
--- `ctx.organization` is normalized to a full https URL so both `--organization`
--- and the generated web URLs are valid.
---@return table|nil
local function context()
	local remote = detect.remote_url()
	local ctx = detect.azure_context(remote)
	if not ctx then
		return nil
	end
	if remote and remote:lower():match("visualstudio%.com") then
		ctx.organization = ("https://%s.visualstudio.com"):format(ctx.organization)
	else
		ctx.organization = ("https://dev.azure.com/%s"):format(ctx.organization)
	end
	return ctx
end

--- `az repos` needs either explicit context flags or --detect.
---@return string[]
local function context_args()
	local ctx = context()
	if not ctx then
		return { "--detect", "true" }
	end
	local args = { "--organization", ctx.organization, "--project", ctx.project }
	if ctx.repository ~= "" then
		vim.list_extend(args, { "--repository", ctx.repository })
	end
	return args
end

local function run(args, opts, cb)
	base.run(vim.list_extend({ M.cli }, args), opts, cb)
end

function M.create(opts, cb)
	local args = { "repos", "pr", "create" }
	opts = vim.deepcopy(opts or {})
	if not opts.source or base.trim(opts.source) == "" then
		opts.source = base.current_branch()
	end
	vim.list_extend(args, base.create_args("azure", opts))
	vim.list_extend(args, context_args())
	vim.list_extend(args, { "--output", "json" })
	run(args, {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		local item = base.normalize("azure", data, context())
		cb(nil, item.url)
	end)
end

function M.list(opts, cb)
	opts = opts or {}
	local status = ({
		all = "all",
		closed = "abandoned",
		merged = "completed",
		open = "active",
	})[opts.state or "open"] or "active"
	local args = { "repos", "pr", "list", "--status", status, "--top", tostring(opts.limit or 50) }
	if opts.author and base.trim(opts.author) ~= "" then
		vim.list_extend(args, { "--creator", opts.author })
	end
	vim.list_extend(args, context_args())
	vim.list_extend(args, { "--output", "json" })
	run(args, {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		local ctx = context()
		local items = {}
		for _, item in ipairs(data) do
			items[#items + 1] = base.normalize("azure", item, ctx)
		end
		cb(nil, items)
	end)
end

function M.view(id, cb)
	local args = { "repos", "pr", "show", "--id", tostring(id) }
	vim.list_extend(args, context_args())
	vim.list_extend(args, { "--output", "json" })
	run(args, {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		cb(nil, base.normalize("azure", data, context()))
	end)
end

--- Azure has no `pr checkout`; the PR head lives at refs/pull/<id>/head.
function M.checkout(id, cb)
	local ref = ("refs/pull/%s/head"):format(tostring(id))
	local branch = ("pr-%s"):format(tostring(id))
	base.run({ "git", "fetch", "origin", ("%s:%s"):format(ref, branch) }, {}, function()
		-- The ref name differs between Azure DevOps Server versions, so retry
		-- with the merge ref before giving up.
		local function switch()
			base.run({ "git", "switch", branch }, {}, function(err)
				cb(err)
			end)
		end
		base.run({ "git", "rev-parse", "--verify", branch }, {}, function(err)
			if not err then
				return switch()
			end
			base.run(
				{ "git", "fetch", "origin", ("refs/pull/%s/merge:%s"):format(tostring(id), branch) },
				{},
				function(fetch_err)
					if fetch_err then
						return cb(fetch_err)
					end
					switch()
				end
			)
		end)
	end)
end

function M.merge(id, opts, cb)
	opts = opts or {}
	local merge_args, err = base.merge_args("azure", opts.method)
	if not merge_args then
		return cb(err)
	end
	local args = { "repos", "pr", "update", "--id", tostring(id) }
	vim.list_extend(args, merge_args)
	if opts.delete_branch then
		vim.list_extend(args, { "--delete-source-branch", "true" })
	end
	vim.list_extend(args, context_args())
	vim.list_extend(args, { "--output", "json" })
	run(args, {}, function(run_err)
		cb(run_err)
	end)
end

--- Turn the API URL Azure returns into the browsable one.
---@param url string|nil
---@param id string|nil
---@return string|nil
local function web_url(url, id)
	local ctx = context()
	if ctx and ctx.repository ~= "" then
		return ("%s/%s/_git/%s/pullrequest/%s"):format(ctx.organization, ctx.project, ctx.repository, tostring(id))
	end
	if url then
		return (url:gsub("_apis/git/repositories/([^/]+)/pullRequests/", "_git/%1/pullrequest/"))
	end
	return nil
end

function M.url(id, cb)
	M.view(id, function(err, detail)
		if err then
			return cb(err)
		end
		local url = web_url(detail and detail.url, id)
		if not url then
			return cb("could not build an Azure DevOps web URL; check the git remote or provider config")
		end
		cb(nil, url)
	end)
end

function M.open_browser(id, cb)
	M.url(id, function(err, url)
		if err then
			return cb(err)
		end
		if not base.open_url(url, "nvim-pr") then
			return cb(url)
		end
		cb(nil)
	end)
end

--- Organization users, used as candidates for the `br` reviewer picker.
---@param cb fun(err?: string, handles?: string[])
function M.list_reviewers(cb)
	local args = {
		"devops",
		"user",
		"list",
		"--query",
		"members[].user.uniqueName",
		"--output",
		"json",
	}
	vim.list_extend(args, context_args())
	run(args, {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		local handles = {}
		for _, handle in ipairs(data) do
			if type(handle) == "string" and handle ~= "" and not vim.tbl_contains(handles, handle) then
				handles[#handles + 1] = handle
			end
		end
		table.sort(handles)
		cb(nil, handles)
	end)
end

return M
