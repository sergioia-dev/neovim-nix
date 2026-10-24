local base = require("pr.providers.base")

local M = {
	name = "gitlab",
	cli = "glab",
}

function M.is_available()
	return vim.fn.executable(M.cli) == 1
end

function M.create(opts, cb)
	local flags = base.flags.gitlab
	local args = { "mr", "create" }
	if not opts.source or base.trim(opts.source) == "" then
		opts.source = base.current_branch()
	end
	vim.list_extend(args, base.create_args("gitlab", opts))
	-- Always explicit: without it glab opens $EDITOR, which an async job cannot
	-- drive, and without --yes it waits for a submission confirmation.
	if not opts.body or base.trim(opts.body) == "" then
		vim.list_extend(args, { flags.body, "" })
	end
	vim.list_extend(args, { "--no-editor", "--yes" })
	base.run(vim.list_extend({ M.cli }, args), {}, function(err, stdout, stderr)
		if err then
			return cb(err)
		end
		local url = base.url_from(stdout) or base.url_from(stderr)
		if not url then
			return cb("glab created the merge request but did not print its URL")
		end
		cb(nil, url)
	end)
end

function M.list(opts, cb)
	opts = opts or {}
	local state = opts.state or "open"
	local args = { "mr", "list", "--output", "json", "--per-page", tostring(opts.limit or 50) }
	local state_flag = ({
		all = "--all",
		closed = "--closed",
		merged = "--merged",
		open = "--opened",
	})[state]
	if state_flag then
		args[#args + 1] = state_flag
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
			items[#items + 1] = base.normalize("gitlab", item)
		end
		cb(nil, items)
	end)
end

function M.view(id, cb)
	local args = { "mr", "view" }
	if id and tostring(id) ~= "" then
		args[#args + 1] = tostring(id)
	end
	vim.list_extend(args, { "--output", "json" })
	base.run(vim.list_extend({ M.cli }, args), {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local data, decode_err = base.decode(stdout)
		if not data then
			return cb(decode_err)
		end
		cb(nil, base.normalize("gitlab", data))
	end)
end

function M.checkout(id, cb)
	base.run({ M.cli, "mr", "checkout", tostring(id) }, {}, function(err)
		cb(err)
	end)
end

function M.merge(id, opts, cb)
	opts = opts or {}
	local args = { "mr", "merge", tostring(id) }
	local merge_args, err = base.merge_args("gitlab", opts.method)
	if not merge_args then
		return cb(err)
	end
	vim.list_extend(args, merge_args)
	if opts.delete_branch then
		args[#args + 1] = "--remove-source-branch"
	end
	base.run(vim.list_extend({ M.cli }, args), {}, function(run_err)
		cb(run_err)
	end)
end

--- Resolve the web URL, so the fallback (printing the link) still works headless.
function M.url(id, cb)
	M.view(id, function(err, detail)
		if err then
			return cb(err)
		end
		if not detail or not detail.url then
			return cb("glab did not report a web URL for this merge request")
		end
		cb(nil, detail.url)
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

--- Project members' usernames, used as candidates for the `br` reviewer picker.
---@param cb fun(err?: string, handles?: string[])
function M.list_reviewers(cb)
	base.run({ M.cli, "api", "projects/:id/members/all?per_page=100" }, {}, function(err, stdout)
		if err then
			return cb(err)
		end
		local handles = {}
		for username in stdout:gmatch('"username"%s*:%s*"([^"]+)"') do
			if not vim.tbl_contains(handles, username) then
				handles[#handles + 1] = username
			end
		end
		table.sort(handles)
		cb(nil, handles)
	end)
end

return M
