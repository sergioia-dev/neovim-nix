local M = {}

-- Unified option name -> per-provider CLI flag. Keeping the mapping here means
-- no provider module has to know what a `--body` is called on another CLI.
M.flags = {
	github = {
		title = "--title",
		body = "--body",
		base = "--base",
		draft = "--draft",
		reviewers = "--reviewer",
		source = "--head",
	},
	gitlab = {
		title = "--title",
		body = "--description",
		base = "--target-branch",
		draft = "--draft",
		reviewers = "--reviewer",
		source = "--source-branch",
	},
	azure = {
		title = "--title",
		body = "--description",
		base = "--target-branch",
		draft = "--draft",
		-- `--reviewers` takes a space-separated list, so every value goes in
		-- as its own argv element instead of one quoted string.
		reviewers = "--reviewers",
		source = "--source-branch",
	},
}

function M.trim(value)
	return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Branch name as the CLIs want it.
--- The picker offers remote branches as `origin/main`, which is what the draft
--- buffer should show, but every CLI expects the bare branch name, so the
--- remote and `refs/heads/` prefixes are dropped right before the argv is built.
---@param value string|nil
---@return string|nil
function M.plain_branch(value)
	if type(value) ~= "string" then
		return value
	end
	return (value:gsub("^refs/remotes/[^/]+/", ""):gsub("^refs/heads/", ""):gsub("^origin/", ""))
end

--- Run a command asynchronously.
---@param cmd string[]
---@param opts table|nil { cwd, env }
---@param cb fun(err?: string, stdout?: string, stderr?: string)
function M.run(cmd, opts, cb)
	opts = opts or {}
	-- Every CLI resolves the repository from the process directory, so pin the
	-- calls to the repository we detected instead of whatever `:cd` left behind.
	local cwd = opts.cwd or require("pr.detect").root()
	local ok, err = pcall(vim.system, cmd, {
		text = true,
		cwd = cwd,
		env = opts.env,
	}, function(out)
		-- vim.system callbacks run in a fast event; every caller touches the UI.
		vim.schedule(function()
			if out.code ~= 0 then
				local message = M.trim(out.stderr)
				if message == "" then
					message = M.trim(out.stdout)
				end
				if message == "" then
					message = ("%s exited with code %d"):format(cmd[1], out.code)
				end
				cb(message, out.stdout or "", out.stderr or "")
				return
			end
			cb(nil, out.stdout or "", out.stderr or "")
		end)
	end)
	if not ok then
		cb(("could not run %s: %s"):format(cmd[1], err))
	end
end

--- Decode JSON, reporting a readable error instead of throwing.
---@param raw string|nil
---@return any|nil
---@return string|nil
function M.decode(raw)
	if not raw or M.trim(raw) == "" then
		return nil, "the CLI returned no JSON output"
	end
	local ok, data = pcall(vim.json.decode, raw)
	if not ok or data == nil then
		return nil, "could not parse the CLI's JSON output"
	end
	return data
end

--- First URL in a block of text, with trailing punctuation stripped.
---@param text string|nil
---@return string|nil
function M.url_from(text)
	local url = (text or ""):match("https?://[^%s\"'<>]+")
	if not url then
		return nil
	end
	return (url:gsub("[),.;]+$", ""))
end

function M.current_branch()
	local out = vim.fn.systemlist({ "git", "rev-parse", "--abbrev-ref", "HEAD" })
	if vim.v.shell_error ~= 0 then
		return nil
	end
	local branch = M.trim(out[1])
	if branch == "" or branch == "HEAD" then
		return nil
	end
	return branch
end

local function plain_handle(handle)
	return (M.trim(tostring(handle)):gsub("^@", ""))
end

--- Normalise reviewers into a list of plain handles (no leading `@`).
---@param reviewers string|string[]|nil
---@return string[]
local function reviewer_list(reviewers)
	local values = reviewers
	if type(values) == "string" then
		if M.trim(values) == "" then
			return {}
		end
		values = vim.split(values, ",", { trimempty = true })
	end
	if type(values) ~= "table" then
		return {}
	end
	local handles = {}
	for _, handle in ipairs(values) do
		local plain = plain_handle(handle)
		if plain ~= "" and not vim.tbl_contains(handles, plain) then
			handles[#handles + 1] = plain
		end
	end
	return handles
end

--- Build the provider's `create` argv (without the executable).
---@param kind string "github"|"gitlab"|"azure"
---@param opts table { title, body, base, draft, reviewers, source }
---@return string[]
function M.create_args(kind, opts)
	local flags = M.flags[kind]
	local args = {}

	if opts.title and opts.title ~= "" then
		vim.list_extend(args, { flags.title, opts.title })
	end
	if opts.body and opts.body ~= "" then
		vim.list_extend(args, { flags.body, opts.body })
	end
	if opts.base and opts.base ~= "" then
		vim.list_extend(args, { flags.base, M.plain_branch(opts.base) })
	end
	if opts.source and opts.source ~= "" then
		vim.list_extend(args, { flags.source, M.plain_branch(opts.source) })
	end
	if opts.draft then
		args[#args + 1] = flags.draft
	end
	local reviewers = reviewer_list(opts.reviewers)
	if #reviewers > 0 then
		if kind == "azure" then
			-- One flag, several values: `--reviewers a b` (emails/GUIDs only).
			args[#args + 1] = flags.reviewers
			vim.list_extend(args, reviewers)
		else
			for _, reviewer in ipairs(reviewers) do
				vim.list_extend(args, { flags.reviewers, reviewer })
			end
		end
	end
	return args
end

--- Provider-specific merge flags.
---@param kind string
---@param method string|nil "merge"|"squash"|"rebase"
---@return string[]
function M.merge_args(kind, method)
	method = method or "merge"
	local args = {}
	if kind == "github" then
		args = { "--" .. method }
	elseif kind == "gitlab" then
		if method == "merge" then
			args = {}
		else
			args = { "--" .. method }
		end
		args[#args + 1] = "--yes"
	elseif kind == "azure" then
		args = { "--status", "completed" }
		if method == "squash" then
			vim.list_extend(args, { "--squash", "true" })
		elseif method == "rebase" then
			return nil, "Azure DevOps cannot rebase through the CLI; use method=merge or method=squash"
		end
	end
	return args
end

local normalizers = {}

-- Field names diverge per CLI; this is the only place that knows about them.
normalizers.github = function(item)
	return {
		id = tostring(item.number or ""),
		number = item.number,
		title = item.title,
		url = item.url,
		author = item.author and item.author.login or nil,
		state = item.state,
		base_branch = item.baseRefName,
		head_branch = item.headRefName,
		draft = item.isDraft,
		created_at = item.createdAt,
		updated_at = item.updatedAt,
		body = item.body,
		additions = item.additions,
		deletions = item.deletions,
		changed_files = item.changedFiles,
	}
end

normalizers.gitlab = function(item)
	return {
		id = tostring(item.iid or item.id or ""),
		number = item.iid,
		title = item.title,
		url = item.web_url,
		author = item.author and item.author.username or nil,
		state = item.state,
		base_branch = item.target_branch,
		head_branch = item.source_branch,
		draft = item.draft or item.work_in_progress,
		created_at = item.created_at,
		updated_at = item.updated_at,
		body = item.description,
	}
end

--- One path segment of a web URL. Project names reach the CLI decoded
--- (`419 - DEPOSITOS JUDICIALES`), so a browsable URL has to encode them again.
---@param segment string|nil
---@return string
function M.url_segment(segment)
	return (tostring(segment or ""):gsub("[^%w%-%._~]", function(char)
		return ("%%%02X"):format(char:byte())
	end))
end

normalizers.azure = function(item, ctx)
	local id = tostring(item.pullRequestId or "")
	local url = item.url
	if ctx and ctx.organization and ctx.project then
		local organization = ctx.organization:gsub("/+$", "")
		if organization:match("visualstudio%.com") then
			organization = organization:gsub("^https?://", ""):gsub("/+$", "")
			url = ("https://%s/%s/_git/%s/pullrequest/%s"):format(
				organization,
				M.url_segment(ctx.project),
				M.url_segment(ctx.repository or ""),
				id
			)
		else
			local org = organization:gsub("^https?://dev%.azure%.com/?", "")
			url = ("https://dev.azure.com/%s/%s/_git/%s/pullrequest/%s"):format(
				org,
				M.url_segment(ctx.project),
				M.url_segment(ctx.repository or ""),
				id
			)
		end
	end
	return {
		id = id,
		number = item.pullRequestId,
		title = item.title,
		url = url,
		author = item.createdBy and (item.createdBy.displayName or item.createdBy.uniqueName) or nil,
		state = item.status,
		base_branch = (item.targetRefName or ""):gsub("^refs/heads/", ""),
		head_branch = (item.sourceRefName or ""):gsub("^refs/heads/", ""),
		draft = item.isDraft,
		created_at = item.creationDate,
		updated_at = item.closedDate,
		body = item.description,
	}
end

--- Turn a raw CLI item into a PRItem.
---@param kind string
---@param item table
---@param ctx table|nil Azure context
---@return table
function M.normalize(kind, item, ctx)
	local normalize = normalizers[kind]
	if not normalize then
		return item
	end
	return normalize(item, ctx)
end

--- Open a URL in the user's browser, falling back to the notification text.
---@param url string|nil
---@param label string|nil
function M.open_url(url, label)
	if not url or url == "" then
		return false
	end
	-- `vim.ui.open` returns the spawned `vim.system` handle when it succeeds, so
	-- only a broken pcall counts as a failure.
	if pcall(vim.ui.open, url) then
		return true
	end
	-- No browser handler here (headless session, no xdg-open): show the URL
	-- instead, so it can still be copied out of the message.
	vim.notify(("%s: %s"):format(label or "nvim-pr", url), vim.log.levels.INFO)
	return false
end

return M
