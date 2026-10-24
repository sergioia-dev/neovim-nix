local base = require("pr.providers.base")

local M = {
	name = "github",
	cli = "gh",
}

local LIST_FIELDS = table.concat({
	"number",
	"title",
	"url",
	"author",
	"state",
	"baseRefName",
	"headRefName",
	"isDraft",
	"createdAt",
	"updatedAt",
}, ",")

local VIEW_FIELDS = LIST_FIELDS
	.. ",body,"
	.. table.concat({
		"additions",
		"deletions",
		"changedFiles",
		"mergeable",
	}, ",")

function M.is_available()
	return vim.fn.executable(M.cli) == 1
end

---@param opts table
---@return string[]
local function argv(opts)
	local flags = base.flags.github
	local args = { "pr", "create" }
	vim.list_extend(args, base.create_args("github", opts))
	-- gh opens an interactive prompt when it gets no body at all, which would
	-- hang an async job; an explicit empty body keeps it non-interactive.
	if not opts.body or base.trim(opts.body) == "" then
		vim.list_extend(args, { flags.body, "" })
	end
	return args
end

function M.create(opts, cb)
	base.run(vim.list_extend({ M.cli }, argv(opts)), {}, function(err, stdout, stderr)
		if err then
			return cb(err)
		end
		-- `gh pr create` prints the new URL on stdout (sometimes after warnings).
		local url = base.url_from(stdout) or base.url_from(stderr)
		if not url then
			return cb("gh created the pull request but did not print its URL")
		end
		cb(nil, url)
	end)
end

function M.list(opts, cb)
	opts = opts or {}
	local state = opts.state or "open"
	local args = { "pr", "list", "--json", LIST_FIELDS, "--limit", tostring(opts.limit or 50) }
	if state ~= "open" then
		vim.list_extend(args, { "--state", state })
	end
	if opts.author and base.trim(opts.author) ~= "" then
		vim.list_extend(args, { "--author", opts.author })
	end
	base.run(vim.list_extend({ M.cli }, args), {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		local items = {}
		for _, item in ipairs(data) do
			items[#items + 1] = base.normalize("github", item)
		end
		cb(nil, items)
	end)
end

function M.view(id, cb)
	local args = { "pr", "view" }
	if id and tostring(id) ~= "" then
		args[#args + 1] = tostring(id)
	end
	vim.list_extend(args, { "--json", VIEW_FIELDS })
	base.run(vim.list_extend({ M.cli }, args), {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		cb(nil, base.normalize("github", data))
	end)
end

function M.checkout(id, cb)
	base.run({ M.cli, "pr", "checkout", tostring(id) }, {}, function(err)
		cb(err)
	end)
end

function M.merge(id, opts, cb)
	opts = opts or {}
	local args = { "pr", "merge", tostring(id) }
	local merge_args, err = base.merge_args("github", opts.method)
	if not merge_args then
		return cb(err)
	end
	vim.list_extend(args, merge_args)
	if opts.delete_branch then
		args[#args + 1] = "--delete-branch"
	end
	base.run(vim.list_extend({ M.cli }, args), {}, function(run_err)
		cb(run_err)
	end)
end

--- Resolve the web URL, so the fallback (printing the link) still works headless.
function M.url(id, cb)
	local args = { "pr", "view" }
	if id and tostring(id) ~= "" then
		args[#args + 1] = tostring(id)
	end
	vim.list_extend(args, { "--json", "url" })
	base.run(vim.list_extend({ M.cli }, args), {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		cb(nil, data.url)
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

return M
