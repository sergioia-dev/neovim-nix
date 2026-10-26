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
--- Only `pr create` and `pr list` accept `--project` and `--repository`;
--- `pr show`, `pr update` and `devops user list` take the organization alone
--- and fail with "unrecognized arguments" when handed the whole context.
---@param scope string|nil "organization" to leave project and repository out
---@return string[]
local function context_args(scope)
	local ctx = context()
	if not ctx then
		return { "--detect", "true" }
	end
	local args = { "--organization", ctx.organization }
	if scope ~= "organization" then
		vim.list_extend(args, { "--project", ctx.project })
		if ctx.repository ~= "" then
			vim.list_extend(args, { "--repository", ctx.repository })
		end
	end
	return args
end

local function run(args, opts, cb)
	base.run(vim.list_extend({ M.cli }, args), opts, cb)
end

--- The command as it can be pasted into a shell, for error messages.
local function printable(args)
	local parts = { M.cli }
	for _, arg in ipairs(args) do
		local needs_quote = arg:find("[%s'\"]") ~= nil
		parts[#parts + 1] = needs_quote and ("'" .. arg .. "'") or arg
	end
	return table.concat(parts, " ")
end

--- Run an az command against the repository context, retrying once with
--- `--detect` when az answers 404. A 404 means the organization, project or
--- repository the flags named does not exist: nothing was changed, so the
--- retry is safe even for writes, and `--detect` lets az derive the context
--- from the git remote instead of trusting our parse of the origin URL.
--- The error finally reported names every command that was tried.
---@param build fun(ctx_flags: string[]): string[] build the argv of one attempt
---@param cb fun(err: string|nil, stdout: string|nil)
---@param scope string|nil "organization" for subcommands that reject --project/--repository
local function with_context(build, cb, scope)
	local tried = {}
	local function attempt(ctx_flags, retry)
		local args = build(ctx_flags)
		tried[#tried + 1] = printable(args)
		run(args, {}, function(err, stdout)
			if err then
				if retry and err:find("404", 1, true) then
					attempt({ "--detect", "true" }, false)
					return
				end
				-- A single attempt would only repeat the command the user just
				-- saw, so the list is only worth printing when a retry was
				-- involved.
				local lines = { base.trim(err) }
				if #tried > 1 then
					for _, cmd in ipairs(tried) do
						lines[#lines + 1] = "  tried: " .. cmd
					end
				end
				return cb(table.concat(lines, "\n"))
			end
			cb(nil, stdout)
		end)
	end
	local flags = context_args(scope)
	attempt(flags, flags[1] ~= "--detect")
end

--- An active pull request between these two branches already exists, so the
--- error can point at it instead of at az's error code.
---@param source string
---@param target string
---@param cb fun(url: string|nil)
local function active_between(source, target, cb)
	with_context(function(ctx_flags)
		local args = {
			"repos",
			"pr",
			"list",
			"--source-branch",
			source,
			"--target-branch",
			target,
			"--status",
			"active",
			"--top",
			"1",
		}
		vim.list_extend(args, ctx_flags)
		vim.list_extend(args, { "--output", "json" })
		return args
	end, function(err, stdout)
		if err then
			return cb(nil)
		end
		local data = base.decode(stdout)
		if type(data) ~= "table" or not data[1] then
			return cb(nil)
		end
		cb(base.normalize("azure", data[1], context()).url)
	end)
end


function M.create(opts, cb)
	opts = vim.deepcopy(opts or {})
	if not opts.source or base.trim(opts.source) == "" then
		opts.source = base.current_branch()
	end

	with_context(function(ctx_flags)
		local args = { "repos", "pr", "create" }
		vim.list_extend(args, base.create_args("azure", opts))
		vim.list_extend(args, ctx_flags)
		vim.list_extend(args, { "--output", "json" })
		return args
	end, function(err, stdout)
		if err then
			-- az refuses a second pull request between the same two branches
			-- (TF401179). That is not a failure worth a stack of flags: the
			-- existing request is what the user wants, so report it.
			if err:find("TF401179", 1, true) or err:lower():find("already exists", 1, true) then
				-- The target branch travels as `base` in the shared options.
				local target = opts.base or ""
				if target == "" then
					return cb(("an active pull request from %s already exists"):format(opts.source))
				end
				local where = ("%s -> %s"):format(opts.source, target)
				return active_between(opts.source, target, function(url)
					cb(("an active pull request for %s already exists%s"):format(where, url and (": " .. url) or ""))
				end)
			end
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
	with_context(function(ctx_flags)
		local args = { "repos", "pr", "list", "--status", status, "--top", tostring(opts.limit or 50) }
		if opts.author and base.trim(opts.author) ~= "" then
			vim.list_extend(args, { "--creator", opts.author })
		end
		vim.list_extend(args, ctx_flags)
		vim.list_extend(args, { "--output", "json" })
		return args
	end, function(err, stdout)
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
	with_context(function(ctx_flags)
		local args = { "repos", "pr", "show", "--id", tostring(id) }
		vim.list_extend(args, ctx_flags)
		vim.list_extend(args, { "--output", "json" })
		return args
	end, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		cb(nil, base.normalize("azure", data, context()))
	end, "organization")
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
	with_context(function(ctx_flags)
		local args = { "repos", "pr", "update", "--id", tostring(id) }
		vim.list_extend(args, merge_args)
		if opts.delete_branch then
			vim.list_extend(args, { "--delete-source-branch", "true" })
		end
		vim.list_extend(args, ctx_flags)
		vim.list_extend(args, { "--output", "json" })
		return args
	end, function(run_err)
		cb(run_err)
	end, "organization")
end

--- Turn the API URL Azure returns into the browsable one.
---@param url string|nil
---@param id string|nil
---@return string|nil
local function web_url(url, id)
	local ctx = context()
	if ctx and ctx.repository ~= "" then
		return ("%s/%s/_git/%s/pullrequest/%s"):format(
			ctx.organization,
			base.url_segment(ctx.project),
			base.url_segment(ctx.repository),
			tostring(id)
		)
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
	-- `az devops user list` takes only `--organization`: the `--project` and
	-- `--repository` flags that `context_args()` adds are rejected, so the
	-- context is narrowed to the organization here.
	local ctx = context()
	if ctx then
		vim.list_extend(args, { "--organization", ctx.organization })
	end
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
