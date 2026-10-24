local M = {}

local TITLE_MARKER = "# Title"
local BODY_MARKER = "## Description"
-- Everything from this line down is instructions and is never parsed.
local FOOTER_MARKER = "# ---"

local footer = {
	FOOTER_MARKER,
	"# :w            submit (asks for confirmation)",
	"# :q! or <C-c><C-k>  discard without creating the PR",
	"#",
	"# Lines above `# ---` are the PR itself: the first non-empty line under",
	"# `# Title` is the title, everything under `## Description` is the body.",
}

--- The Markdown skeleton the user edits.
---@param opts table { title, body, base, draft }
---@return string[]
local function template(opts)
	opts = opts or {}
	local lines = { TITLE_MARKER, "" }
	if opts.title and opts.title ~= "" then
		lines[#lines + 1] = opts.title
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = BODY_MARKER
	lines[#lines + 1] = ""
	local body = opts.body or ""
	if body ~= "" then
		for _, line in ipairs(vim.split(body, "\n", { plain = true })) do
			lines[#lines + 1] = line
		end
		lines[#lines + 1] = ""
	end
	vim.list_extend(lines, footer)
	return lines
end

--- Split the buffer into its instructions and the PR fields.
---@param lines string[]
---@return table { title, body }
function M.parse(lines)
	local title, body, in_body = nil, {}, false
	for _, line in ipairs(lines) do
		if line == FOOTER_MARKER then
			break
		elseif line:match("^#%s*Title%s*$") then
			in_body = false
		elseif line:match("^##%s*Description%s*$") then
			in_body = true
		elseif in_body then
			body[#body + 1] = line
		elseif not title and vim.trim(line) ~= "" then
			title = vim.trim(line)
		end
	end
	-- Trim the blank lines the template leaves around the description.
	while #body > 0 and vim.trim(body[1]) == "" do
		table.remove(body, 1)
	end
	while #body > 0 and vim.trim(body[#body]) == "" do
		table.remove(body, #body)
	end
	return { title = title or "", body = table.concat(body, "\n") }
end

--- Ask a yes/no question through vim.ui.select (never a blocking prompt).
---@param message string
---@param cb fun(yes: boolean)
function M.confirm(message, cb)
	vim.ui.select({ "Confirm", "Cancel" }, { prompt = message }, function(choice)
		cb(choice == "Confirm")
	end)
end

--- Buffer name that cannot collide with an earlier draft.
---@return string
local function scratch_name()
	local name = "pr-create.md"
	if vim.fn.bufnr("^" .. vim.pesc(name) .. "$") ~= -1 then
		name = ("pr-create-%d.md"):format(vim.uv.hrtime())
	end
	return name
end

--- Open the `# Title` / `## Description` draft. `on_submit` runs only after the
--- user writes the buffer and confirms; discarding the buffer creates nothing.
---@param opts table create options (used to pre-fill the template)
---@param on_submit fun(opts: table)
function M.create(opts, on_submit)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, scratch_name())
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, template(opts))
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modified = false

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		desc = "nvim-pr: submit the pull request draft",
		callback = function()
			local parsed = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
			if parsed.title == "" then
				-- Erroring keeps the buffer (and 'modified') as it is: `:w` and
				-- `:wq` both stop here instead of submitting an empty draft.
				vim.notify("nvim-pr: write a title under `# Title` first", vim.log.levels.ERROR)
				return
			end
			-- Clear `modified` only now: `:wq` must be able to quit while the
			-- confirmation prompt is open, and cancelling keeps the text.
			vim.bo[buf].modified = false
			M.confirm(('Create pull request "%s"?'):format(parsed.title), function(yes)
				if not yes then
					return
				end
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
				on_submit(vim.tbl_extend("force", opts, parsed))
			end)
		end,
	})

	vim.api.nvim_set_current_buf(buf)
	vim.cmd("startinsert!")
end

--- One line per PR for the pickers.
---@param item table
---@return string
local function label(item)
	local id = (item.id and item.id ~= "") and ("#%s"):format(item.id) or "#?"
	local parts = { ("%s %s"):format(id, item.title or "(no title)") }
	if item.draft then
		parts[#parts + 1] = "[draft]"
	end
	if item.head_branch and item.base_branch then
		parts[#parts + 1] = ("(%s -> %s)"):format(item.head_branch, item.base_branch)
	end
	return table.concat(parts, " ")
end

--- Pick a PR with fzf-lua, falling back to vim.ui.select.
---@param items table[]
---@param on_select fun(item: table)
function M.pick(items, on_select)
	if not items or #items == 0 then
		vim.notify("nvim-pr: no pull requests found", vim.log.levels.INFO)
		return
	end

	local by_label, entries = {}, {}
	for _, item in ipairs(items) do
		local text = label(item)
		by_label[text] = item
		entries[#entries + 1] = text
	end

	local picker = (require("pr.config").get().ui or {}).picker
	if picker == "fzf-lua" then
		local ok, fzf = pcall(require, "fzf-lua")
		if ok then
			fzf.fzf_exec(entries, {
				prompt = "Pull requests> ",
				actions = {
					["default"] = function(selected)
						local item = by_label[selected and selected[1] or ""]
						if item then
							on_select(item)
						end
					end,
				},
			})
			return
		end
	end

	vim.ui.select(entries, {
		prompt = "Pull requests",
		format_item = function(text)
			return text
		end,
	}, function(choice)
		local item = by_label[choice or ""]
		if item then
			on_select(item)
		end
	end)
end

--- Floating window showing one PR.
---@param detail table PRItem
function M.view(detail)
	local lines = { detail.title or "(no title)", "" }
	local meta = {}
	if detail.state then
		meta[#meta + 1] = detail.state
	end
	if detail.author then
		meta[#meta + 1] = "by " .. detail.author
	end
	if detail.draft then
		meta[#meta + 1] = "draft"
	end
	if #meta > 0 then
		lines[#lines + 1] = table.concat(meta, " | ")
	end
	if detail.head_branch and detail.base_branch then
		lines[#lines + 1] = ("%s -> %s"):format(detail.head_branch, detail.base_branch)
	end
	if detail.url then
		lines[#lines + 1] = detail.url
	end
	lines[#lines + 1] = ""
	if detail.body and vim.trim(detail.body) ~= "" then
		vim.list_extend(lines, vim.split(vim.trim(detail.body), "\n", { plain = true }))
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false

	local width = math.min(100, math.max(40, vim.o.columns - 20))
	local height = math.min(#lines, math.max(10, math.floor(vim.o.lines * 0.7)))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		title = ("PR #%s"):format(detail.id or "?"),
		title_pos = "center",
	})

	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end, { buffer = buf, nowait = true, desc = "Close the PR view" })
	end

	local url = detail.url
	if url and url ~= "" then
		vim.keymap.set("n", "gx", function()
			require("pr.providers.base").open_url(url, "nvim-pr")
		end, { buffer = buf, nowait = true, desc = "Open the PR in the browser" })
	end
end

return M
