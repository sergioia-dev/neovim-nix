local config = require("pr.config")
local detect = require("pr.detect")
local git = require("pr.git")
local providers = require("pr.providers")
local ui = require("pr.ui")

local M = {}

M.config = config
M.detect = detect
M.ui = ui
M.providers = providers

local SUBCOMMANDS = { "create", "list", "view", "checkout", "open", "merge", "provider" }

--- Flags each subcommand understands, for `:PR` completion and parsing.
local SUBCOMMAND_FLAGS = {
	create = { "--title", "--body", "--head", "--base", "--reviewers", "--draft" },
	list = { "--state", "--author", "--limit" },
	merge = { "--method", "--delete-branch" },
	view = {},
	checkout = {},
	open = {},
	provider = {},
}

--- Flags that take a value; everything else is a boolean switch.
local VALUED_FLAGS = {
	title = true,
	body = true,
	base = true,
	head = true,
	reviewers = true,
	source = true,
	state = true,
	author = true,
	limit = true,
	method = true,
}

local function notify_error(message)
	vim.notify("nvim-pr: " .. message, vim.log.levels.ERROR)
end

--- Split `:PR` arguments into positionals and `--flags`.
---@param args string[]
---@return string[] positional
---@return table opts
function M.parse_args(args)
	local positional, opts = {}, {}
	local i = 1
	while i <= #args do
		local arg = args[i]
		local flag, inline = arg:match("^%-%-([%w-]+)=(.*)$")
		if not flag then
			flag = arg:match("^%-%-([%w-]+)$")
		end
		if flag then
			local key = flag:gsub("%-", "_")
			if inline then
				opts[key] = inline
			elseif VALUED_FLAGS[key] and args[i + 1] and not args[i + 1]:match("^%-%-") then
				opts[key] = args[i + 1]
				i = i + 1
			else
				opts[key] = true
			end
		else
			positional[#positional + 1] = arg
		end
		i = i + 1
	end
	return positional, opts
end

--- Provider for the current repository, or nil after notifying why not.
---@return table|nil
local function provider()
	local cfg = config.get()
	local name = cfg.default_provider
	if not name or name == "" then
		name = detect.name(nil, cfg)
	end
	if not name then
		notify_error("cannot tell which provider this repo uses; set `default_provider` in setup()")
		return nil
	end
	local resolved = providers.get(name)
	if not resolved then
		notify_error(('provider "%s" is not configured'):format(name))
		return nil
	end
	if not resolved.is_available() then
		notify_error(("%s CLI (%s) is not installed; see :checkhealth pr"):format(name, resolved.cli))
		return nil
	end
	return resolved
end

--- Provider name for the current repo (or the configured override).
---@return string|nil
function M.current_provider()
	local cfg = config.get()
	local name = cfg.default_provider
	if not name or name == "" then
		name = detect.name(nil, cfg)
	end
	return name
end

--- `:PR create` — Markdown draft, then `<C-c><C-c>` submits it.
---@param opts table|nil { title, body, head, base, draft, reviewers }
function M.create(opts)
	opts = opts or {}
	local resolved = provider()
	if not resolved then
		return
	end
	local head = (opts.head and opts.head ~= "") and opts.head or git.current_branch()
	local base = opts.base
	if not base or base == "" then
		base = config.get().default_base
	end
	if not base or base == "" then
		base = git.default_branch()
	end
	ui.create({
		title = opts.title,
		body = opts.body,
		head = head,
		base = base,
		reviewers = opts.reviewers,
		provider = resolved,
	}, function(fields)
		resolved.create({
			title = fields.title,
			body = fields.body,
			source = fields.head,
			base = fields.base,
			draft = opts.draft,
			reviewers = fields.reviewers or opts.reviewers,
		}, function(err, url)
			if err then
				return notify_error(err)
			end
			local message = url and ("pull request created: %s (:PR open to view it)"):format(url)
				or "pull request created"
			vim.notify("nvim-pr: " .. message, vim.log.levels.INFO)
		end)
	end)
end

--- `:PR list` — pick a PR from the open (or requested) ones.
---@param opts table|nil { state, author, limit }
function M.list(opts)
	opts = opts or {}
	local resolved = provider()
	if not resolved then
		return
	end
	resolved.list(opts, function(err, items)
		if err then
			return notify_error(err)
		end
		ui.pick(items, function(item)
			M.view(item.id)
		end)
	end)
end

--- `:PR view [id]` — floating window; without an id, pick from the list.
---@param id string|nil
function M.view(id)
	local resolved = provider()
	if not resolved then
		return
	end
	if not id or id == "" then
		return M.list({})
	end
	resolved.view(id, function(err, detail)
		if err then
			return notify_error(err)
		end
		if not detail then
			return notify_error(("pull request %s not found"):format(id))
		end
		ui.view(detail)
	end)
end

--- `:PR checkout [id]` — check the PR branch out locally.
---@param id string|nil
function M.checkout(id)
	local resolved = provider()
	if not resolved then
		return
	end
	local function checkout(id_to_use)
		resolved.checkout(id_to_use, function(err)
			if err then
				return notify_error(err)
			end
			vim.notify(("nvim-pr: checked out pull request #%s"):format(id_to_use), vim.log.levels.INFO)
		end)
	end
	if id and id ~= "" then
		return checkout(id)
	end
	resolved.list({ state = "open" }, function(err, items)
		if err then
			return notify_error(err)
		end
		ui.pick(items, function(item)
			checkout(item.id)
		end)
	end)
end

--- `:PR open [id]` — open the PR in the browser.
---@param id string|nil
function M.open(id)
	local resolved = provider()
	if not resolved then
		return
	end
	local function open(id_to_use)
		resolved.open_browser(id_to_use, function(err)
			if err then
				notify_error(err)
			end
		end)
	end
	if id and id ~= "" then
		return open(id)
	end
	resolved.list({ state = "open" }, function(err, items)
		if err then
			return notify_error(err)
		end
		ui.pick(items, function(item)
			open(item.id)
		end)
	end)
end

--- `:PR merge [id]` — always confirmed before the CLI runs.
---@param id string|nil
---@param opts table|nil { method, delete_branch }
function M.merge(id, opts)
	opts = opts or {}
	local resolved = provider()
	if not resolved then
		return
	end
	local function merge(id_to_use)
		ui.confirm(("Merge pull request #%s (%s)?"):format(id_to_use, opts.method or "merge"), function(yes)
			if not yes then
				return
			end
			resolved.merge(id_to_use, opts, function(err)
				if err then
					return notify_error(err)
				end
				vim.notify(("nvim-pr: merged pull request #%s"):format(id_to_use), vim.log.levels.INFO)
			end)
		end)
	end
	if id and id ~= "" then
		return merge(id)
	end
	resolved.list({ state = "open" }, function(err, items)
		if err then
			return notify_error(err)
		end
		ui.pick(items, function(item)
			merge(item.id)
		end)
	end)
end

--- `:PR provider` — which CLI is in charge for this repository.
function M.show_provider()
	local cfg = config.get()
	local name, host = detect.name(nil, cfg)
	local lines = {}
	local root = detect.root()
	if root then
		lines[#lines + 1] = ("repository %s"):format(root)
	end
	if name then
		local resolved = providers.get(name)
		local installed = resolved and resolved.is_available()
		lines[#lines + 1] = ("%s detected from %s"):format(name, host or "the git remote")
		lines[#lines + 1] = ("%s CLI: %s"):format(name, installed and ("installed (" .. name .. ")") or "not installed")
	else
		lines[#lines + 1] = "no provider detected from the git remote"
	end
	if cfg.default_provider then
		lines[#lines + 1] = ("configured default_provider: %s"):format(cfg.default_provider)
	end
	vim.notify("nvim-pr: " .. table.concat(lines, "; "), vim.log.levels.INFO)
end

--- Bind the `<Plug>(pr-*)` mappings listed in `config.mappings`.
---@param cfg table|nil
function M.apply_mappings(cfg)
	cfg = cfg or config.get()
	for action, lhs in pairs(cfg.mappings or {}) do
		if type(lhs) == "string" and lhs ~= "" then
			vim.keymap.set("n", lhs, ("<Plug>(pr-%s)"):format(action), {
				remap = true,
				silent = true,
				desc = ("nvim-pr: %s"):format(action),
			})
		end
	end
end

--- `:PR` entry point.
---@param args string[]
function M.dispatch(args)
	local positional, opts = M.parse_args(args)
	local sub = positional[1]

	local actions = {
		checkout = function()
			M.checkout(positional[2])
		end,
		create = function()
			M.create(opts)
		end,
		list = function()
			M.list(opts)
		end,
		merge = function()
			M.merge(positional[2], opts)
		end,
		open = function()
			M.open(positional[2])
		end,
		provider = M.show_provider,
		view = function()
			M.view(positional[2])
		end,
	}

	local action = sub and actions[sub] or nil
	if not action then
		if sub then
			return notify_error(('unknown subcommand "%s"; try :PR list'):format(sub))
		end
		-- Bare `:PR` lists, which is what people reach for most.
		return M.list(opts)
	end
	action()
end

--- `complete=` callback for `:PR`.
---@param arglead string
---@param cmdline string
---@return string[]
local function starts_with(value, prefix)
	return value:sub(1, #prefix) == prefix
end

function M.complete(arglead, cmdline)
	local words = vim.split(cmdline, "%s+", { trimempty = true })
	-- `words[1]` is "PR". The subcommand is still being typed when it is the
	-- last word *and* the argument being completed: `PR cr`, but not `PR cr `.
	local typing_subcommand = #words <= 1 or (#words == 2 and arglead ~= "" and words[2] == arglead)
	if typing_subcommand then
		if starts_with(arglead, "--") then
			return {}
		end
		return vim.tbl_filter(function(name)
			return starts_with(name, arglead)
		end, SUBCOMMANDS)
	end
	local flags = SUBCOMMAND_FLAGS[words[2]] or {}
	return vim.tbl_filter(function(flag)
		return starts_with(flag, arglead)
	end, flags)
end

--- Merge user options and bind the configured mappings.
---@param opts table|nil
---@return table
function M.setup(opts)
	local cfg = config.setup(opts)
	M.apply_mappings(cfg)
	return cfg
end

return M
