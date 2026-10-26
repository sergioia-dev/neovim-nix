local M = {}

local TARGET_PREFIX = "# Target Branch:"
local TITLE_MARKER = "## Title"
local BODY_MARKER = "### Description"
-- Everything from this line down is instructions and is never submitted.
local FOOTER_MARKER = "# ---"

local footer = {
	FOOTER_MARKER,
	"# <C-c><C-c>          create the pull request",
	"# <C-c><C-k>          discard it",
	"# bt                  pick the target branch (right side): where it will merge",
	"# bc                  pick the source branch (left side): the one to be merged",
	"# br                  pick reviewers for the table above",
	"# <Tab>               list the commits; Tab on one shows the files it touches",
	"#                     delete a reviewer by deleting its row",
	"#                     move the x between Optional and Required to flip it",
	"#",
	"# Write the title under `## Title`, the description under `### Description`.",
	"# `#` lines from `# ---` down are instructions: they are never submitted.",
}

--- The `# Target Branch: <head> -> <base>` line: what merges, then where to.
---@param head string|nil
---@param base string|nil
---@return string
local function target_line(head, base)
	return ("%s %s -> %s"):format(TARGET_PREFIX, head or "", base or "")
end

--- The informational line under the target: how much the pull request moves.
---@param stats { commits: integer, files: integer }|nil
---@return string
local function diff_line(stats)
	if not stats then
		return "**… commits · … files changed**"
	end
	return ("**%d commits · %d files changed**"):format(stats.commits, stats.files)
end

--- Index of the diff summary line, or nil when the user deleted it.
---@param lines string[]
---@return integer|nil
local function diff_index(lines)
	for index, line in ipairs(lines) do
		if line:match("^%*%*.*commits.*files changed%*%*$") then
			return index
		end
	end
	return nil
end

--- `Tab` under the summary expands it into the commits it counts, and `Tab` on
--- one of those commits shows the files it touches. Those rows are ordinary
--- markdown, so they can be edited away by hand too, and they never reach the
--- provider: that only reads the title, the description and the reviewer table.

--- A row that names a commit in the expanded list.
---@param line string
---@return boolean
local function commit_row(line)
	return line:match("^%- ") ~= nil
end

--- A row that names a file under a commit in the expanded list.
---@param line string
---@return boolean
local function file_row(line)
	return line:match("^%s+%- ") ~= nil
end

--- The commits the summary line was expanded into, if any.
---@param lines string[]
---@return integer|nil first, integer|nil last
local function commits_range(lines)
	local index = diff_index(lines)
	if not index then
		return nil, nil
	end
	local first, last
	for row = index + 1, #lines do
		if not commit_row(lines[row]) then
			break
		end
		first = first or row
		last = row
	end
	return first, last
end

--- The whole expanded block: the commit rows plus whatever files are open under
--- them, so closing the summary closes those too.
---@param lines string[]
---@return integer|nil first, integer|nil last
local function expand_range(lines)
	local index = diff_index(lines)
	if not index then
		return nil, nil
	end
	local first, last
	for row = index + 1, #lines do
		if not (commit_row(lines[row]) or file_row(lines[row])) then
			break
		end
		first = first or row
		last = row
	end
	return first, last
end

--- The files open under one commit row.
---@param lines string[]
---@param row integer
---@return integer|nil first, integer|nil last
local function files_range(lines, row)
	local first, last
	for index = row + 1, #lines do
		if not file_row(lines[index]) then
			break
		end
		first = first or index
		last = index
	end
	return first, last
end

--- What `git.changes` said about each buffer's branches, so reopening one
--- commit's files does not ask git again. Dropped whenever the branches change.
---@type table<integer, { sha: string, subject: string, files: string[] }[]|nil>
local changes_cache = {}

--- Remove the expanded commit list, leaving every other line alone.
---@param buf integer
local function collapse_commits(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	changes_cache[buf] = nil
	local first, last = expand_range(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	if not first then
		return false
	end
	vim.api.nvim_buf_set_lines(buf, first - 1, last, false, {})
	return true
end

--- Recompute the diff summary from the buffer's branches and rewrite that
--- one line. Safe to call after the buffer is gone.
---@param buf integer
local function refresh_stat(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	-- The branches changed, so a list of what they contained no longer holds.
	collapse_commits(buf)
	local parsed = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	require("pr.git").diff_stat(parsed.head, parsed.base, function(stats)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local index = diff_index(lines)
		if index then
			vim.api.nvim_buf_set_lines(buf, index - 1, index, false, { diff_line(stats) })
		end
	end)
end

--- The rows the summary line expands into: one `- <sha> <subject>` per commit.
---@param commits { sha: string, subject: string, files: string[] }[]|nil
---@return string[]
local function commit_lines(commits)
	if not commits then
		return { "- … unknown: these branches cannot be compared" }
	end
	if #commits == 0 then
		return { "- … nothing to list: the branches match" }
	end
	local out = {}
	for _, commit in ipairs(commits) do
		out[#out + 1] = ("- %s %s"):format(commit.sha, commit.subject)
	end
	return out
end

--- The rows one commit expands into: every file it touches, indented with a
--- tab. Nothing is summarised away, so a commit that touches 300 files lists
--- 300 files.
---@param commit { sha: string, subject: string, files: string[] }
---@return string[]
local function file_lines(commit)
	if #commit.files == 0 then
		return { "\t- … no files" }
	end
	local out = {}
	for _, file in ipairs(commit.files) do
		out[#out + 1] = "\t- " .. file
	end
	return out
end

--- `Tab` on the summary line: show the commits behind it, or take them away
--- again.
---@param buf integer
local function toggle_commits(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local first, last = commits_range(lines)
	if first then
		local _, block_last = expand_range(lines)
		vim.api.nvim_buf_set_lines(buf, first - 1, block_last or last, false, {})
		changes_cache[buf] = nil
		return
	end
	local index = diff_index(lines)
	if not index then
		return
	end
	local parsed = M.parse(lines)
	vim.api.nvim_buf_set_lines(buf, index, index, false, { "- …" })
	require("pr.git").changes(parsed.head, parsed.base, function(commits)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		changes_cache[buf] = commits
		local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local placeholder = commits_range(current)
		if placeholder then
			vim.api.nvim_buf_set_lines(buf, placeholder - 1, placeholder, false, {})
		end
		local anchor = diff_index(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		if anchor then
			vim.api.nvim_buf_set_lines(buf, anchor, anchor, false, commit_lines(commits))
		end
	end)
end

--- `Tab` on a commit row: show the files it touches, or take them away again.
---@param buf integer
---@param row integer
local function toggle_files(buf, row)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local sha = lines[row] and lines[row]:match("^%- (%x+)")
	if not sha then
		return
	end
	local first, last = files_range(lines, row)
	if first then
		vim.api.nvim_buf_set_lines(buf, first - 1, last, false, {})
		return
	end
	local function show(commits)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local commit
		for _, candidate in ipairs(commits or {}) do
			if candidate.sha == sha then
				commit = candidate
			end
		end
		if not commit then
			return
		end
		-- Find the row again: git may have answered after the text moved.
		for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			if line:match("^%- " .. sha .. " ") then
				vim.api.nvim_buf_set_lines(buf, index, index, false, file_lines(commit))
				return
			end
		end
	end
	local cached = changes_cache[buf]
	if cached then
		show(cached)
		return
	end
	local parsed = M.parse(lines)
	require("pr.git").changes(parsed.head, parsed.base, function(commits)
		changes_cache[buf] = commits
		show(commits)
	end)
end

--- Freshly opened drafts show the placeholder; `refresh_stat` fills it in.

--- The reviewers table: every row is one person, marked optional or required.
local REVIEWER_HEADER = "| Reviewer | Optional | Required |"
local REVIEWER_SEPARATOR = "| --- | --- | --- |"
local TICK = "x"

--- One reviewers-table row, with the mark in the Optional or Required column.
---@param handle string
---@param kind string|nil "optional"|"required"
---@return string
local function reviewer_row(handle, kind)
	local required = kind == "required"
	return ("| %s | %s | %s |"):format(handle, required and "" or TICK, required and TICK or "")
end

--- Reviewer handles from the `--reviewers` flag (table or comma-separated string).
---@param value table|string|nil
---@return string[]
local function reviewer_handles(value)
	if type(value) == "table" then
		return value
	end
	if type(value) ~= "string" or vim.trim(value) == "" then
		return {}
	end
	local handles = {}
	for _, entry in ipairs(vim.split(value, ",")) do
		local handle = vim.trim(entry)
		if handle ~= "" then
			handles[#handles + 1] = handle
		end
	end
	return handles
end

--- Whether `line` is a table row with no name in it: a row someone added by
--- hand and left blank, which is dropped rather than submitted.
---@param line string
---@return boolean
local function blank_reviewer_row(line)
	local handle = line:match("^|%s*(.-)%s*|")
	return handle ~= nil and vim.trim(handle) == ""
end

--- One parsed reviewers-table row; nil for the header, the separator and blanks.
---@param line string
---@return table|nil { handle, kind }
local function parse_reviewer_row(line)
	local handle, optional, required = line:match("^|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*$")
	if not handle or vim.trim(handle) == "" then
		return nil
	end
	if handle:match("^%-+$") or handle == "Reviewer" then
		return nil
	end
	local marked_required = required ~= nil and vim.trim(required) ~= ""
	local marked_optional = optional ~= nil and vim.trim(optional) ~= ""
	-- Any mark in a column counts (`x` in the template, but hand-typed boxes too).
	-- A row with no mark at all is treated as Optional, like the picker default.
	return { handle = handle, kind = (marked_required and not marked_optional) and "required" or "optional" }
end

--- The Markdown skeleton the user edits.
---@param opts table { title, body, head, base, reviewers }
---@return string[]
local function template(opts)
	opts = opts or {}
	-- Target line, then the informational summary of what the PR would move,
	-- then the reviewers table (rows are appended by `br`).
	local lines = {
		target_line(opts.head, opts.base),
		"",
		diff_line(nil),
		"",
		REVIEWER_HEADER,
		REVIEWER_SEPARATOR,
	}
	local handles = reviewer_handles(opts.reviewers)
	for _, handle in ipairs(handles) do
		lines[#lines + 1] = reviewer_row(handle, "optional")
	end
	vim.list_extend(lines, { "", TITLE_MARKER, "" })
	if opts.title and opts.title ~= "" then
		vim.list_extend(lines, vim.split(opts.title, "\n", { plain = true }))
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = BODY_MARKER
	lines[#lines + 1] = ""
	local body = opts.body or ""
	if body ~= "" then
		vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
		lines[#lines + 1] = ""
	end
	vim.list_extend(lines, footer)
	return lines
end

--- Split the buffer into its instructions and the PR fields.
---@param lines string[]
---@return table { title, body, head, base, reviewers }
function M.parse(lines)
	local title, body, head, base = nil, {}, nil, nil
	local reviewers = {}
	local in_title, in_body, in_reviewers = false, false, false
	for _, line in ipairs(lines) do
		if line:match("^#%s*%-%-%-%s*$") then
			break
		end
		local head_part, base_part = line:match("^#%s*Target Branch:%s*(.-)%s*->%s*(.-)%s*$")
		if head_part or base_part then
			in_title, in_body, in_reviewers = false, false, true
			head = head_part ~= "" and head_part or nil
			base = base_part ~= "" and base_part or nil
		elseif line:match("^##%s*Title%s*$") then
			in_title, in_body, in_reviewers = true, false, false
		elseif line:match("^###%s*Description%s*$") then
			in_title, in_body, in_reviewers = false, true, false
		elseif in_body then
			body[#body + 1] = line
		elseif in_reviewers then
			local row = parse_reviewer_row(line)
			if row then
				reviewers[#reviewers + 1] = row
			end
		elseif in_title and not title and vim.trim(line) ~= "" then
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
	return {
		title = title or "",
		body = table.concat(body, "\n"),
		head = head,
		base = base,
		reviewers = reviewers,
	}
end

--- Ask a yes/no question through vim.ui.select (never a blocking prompt).
---@param message string
---@param cb fun(yes: boolean)
function M.confirm(message, cb)
	vim.ui.select({ "Confirm", "Cancel" }, { prompt = message }, function(choice)
		cb(choice == "Confirm")
	end)
end

--- Reorder so the current value leads: both pickers open on the first entry.
---@param entries string[]
---@param current string|nil
---@return string[]
local function current_first(entries, current)
	local ordered, seen = {}, {}
	if current and current ~= "" then
		for _, entry in ipairs(entries) do
			if entry == current then
				ordered[#ordered + 1] = entry
				seen[entry] = true
				break
			end
		end
	end
	for _, entry in ipairs(entries) do
		if not seen[entry] then
			seen[entry] = true
			ordered[#ordered + 1] = entry
		end
	end
	return ordered
end

--- Pick one string with fzf-lua, falling back to vim.ui.select.
---@param entries string[]
---@param opts table { prompt, current, empty }
---@param on_select fun(value: string)
local function pick_string(entries, opts, on_select)
	opts = opts or {}
	if not entries or #entries == 0 then
		vim.notify("nvim-pr: " .. (opts.empty or "nothing to pick from"), vim.log.levels.WARN)
		return
	end
	local ordered = current_first(entries, opts.current)

	local picker = (require("pr.config").get().ui or {}).picker
	if picker == "fzf-lua" then
		local ok, fzf = pcall(require, "fzf-lua")
		if ok and type(fzf.fzf_exec) == "function" then
			fzf.fzf_exec(ordered, {
				prompt = opts.prompt or "> ",
				actions = {
					["default"] = function(selected)
						local value = selected and selected[1]
						if value and value ~= "" then
							on_select(value)
						end
					end,
				},
			})
			return
		end
	end

	vim.ui.select(ordered, {
		prompt = opts.prompt or "Pick one",
		format_item = function(entry)
			return entry
		end,
	}, function(choice)
		if choice then
			on_select(choice)
		end
	end)
end

--- Pick a branch: remote-tracking ones for the target, local ones for the source.
---@param kind "base"|"head"
---@param current string|nil
---@param on_select fun(branch: string)
function M.pick_branch(kind, current, on_select)
	local git = require("pr.git")
	local is_base = kind == "base"
	pick_string(is_base and git.remote_branches() or git.local_branches(), {
		prompt = is_base and "Target branch (right side): where it will be merged> "
			or "Source branch (left side): the one to be merged> ",
		current = current,
		empty = is_base and "no branches found on the `origin` remote" or "no local branches found",
	}, on_select)
end

--- Buffer name that cannot collide with an earlier draft.
---@return string
local function scratch_name()
	local taken = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if name ~= "" then
			taken[vim.fs.basename(name)] = true
		end
	end
	if not taken["pr-create.md"] then
		return "pr-create.md"
	end
	local index = 2
	while taken[("pr-create-%d.md"):format(index)] do
		index = index + 1
	end
	return ("pr-create-%d.md"):format(index)
end

--- Index of the `# Target Branch:` line, or nil.
---@param lines string[]
---@return integer|nil
local function target_index(lines)
	for index, line in ipairs(lines) do
		if line:match("^#%s*Target Branch:") then
			return index
		end
	end
	return nil
end

--- Rewrite one side of the `# Target Branch:` line in place.
---@param buf integer
---@param side "head"|"base"
---@param branch string
local function set_target(buf, side, branch)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local index = target_index(lines)
	if not index then
		return
	end
	local head, base = lines[index]:match("^#%s*Target Branch:%s*(.-)%s*->%s*(.-)%s*$")
	head, base = head or "", base or ""
	if side == "head" then
		head = branch
	else
		base = branch
	end
	vim.api.nvim_buf_set_lines(buf, index - 1, index, false, { target_line(head, base) })
end
--- Multi-select strings: fzf-lua with `--multi`, else one vim.ui.select per pick.
---@param entries string[]
---@param opts table { prompt }
---@param on_done fun(values: string[])
local function pick_many(entries, opts, on_done)
	opts = opts or {}
	if not entries or #entries == 0 then
		on_done({})
		return
	end
	local picker = (require("pr.config").get().ui or {}).picker
	if picker == "fzf-lua" then
		local ok, fzf = pcall(require, "fzf-lua")
		if ok and type(fzf.fzf_exec) == "function" then
			fzf.fzf_exec(entries, {
				prompt = opts.prompt or "> ",
				fzf_opts = { ["--multi"] = "" },
				actions = {
					["default"] = function(selected)
						local values = {}
						for _, value in ipairs(selected or {}) do
							if value ~= "" then
								values[#values + 1] = value
							end
						end
						on_done(values)
					end,
				},
			})
			return
		end
	end

	-- vim.ui.select picks one item at a time, so keep asking until `Done`.
	local chosen, remaining = {}, {}
	for _, entry in ipairs(entries) do
		remaining[#remaining + 1] = entry
	end
	local function step()
		if #remaining == 0 then
			on_done(chosen)
			return
		end
		local menu = { "Done" }
		vim.list_extend(menu, remaining)
		vim.ui.select(menu, { prompt = opts.prompt or "Pick reviewers" }, function(choice)
			if type(choice) ~= "string" or choice == "Done" then
				on_done(chosen)
				return
			end
			local removed = false
			for index, entry in ipairs(remaining) do
				if entry == choice then
					table.remove(remaining, index)
					removed = true
					break
				end
			end
			if not removed then
				-- A picker that answers with something outside the menu must not
				-- spin forever; treat it as "finished".
				on_done(chosen)
				return
			end
			chosen[#chosen + 1] = choice
			step()
		end)
	end
	step()
end

--- Index of the reviewers-table header inside the draft.
---@param lines string[]
---@return integer|nil
local function reviewer_table_index(lines)
	for index, line in ipairs(lines) do
		if line:match("^|%s*Reviewer%s*|") then
			return index
		end
	end
	return nil
end

--- Append reviewer rows directly below the table's separator line.
---@param buf integer
---@param handles string[]
---@param kind string "optional"|"required"
local function add_reviewers(buf, handles, kind)
	if not handles or #handles == 0 then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local index = reviewer_table_index(lines)
	if not index then
		return
	end
	-- The table's own rows, which is where the empty placeholder may sit.
	local last = index + 1
	for row = index + 2, #lines do
		if not lines[row]:match("^|") then
			break
		end
		last = row
	end
	local rows = {}
	for row = index + 2, last do
		if not blank_reviewer_row(lines[row]) then
			rows[#rows + 1] = lines[row]
		end
	end
	for _, handle in ipairs(handles) do
		rows[#rows + 1] = reviewer_row(handle, kind)
	end
	-- `index` is the 1-based header, so the separator sits on `index + 1` and
	-- the rows start on `index + 2`: rewritten in one go, empty row included.
	vim.api.nvim_buf_set_lines(buf, index + 1, last, false, rows)
end

--- Always present in the reviewer picker: add a handle the provider did not list.
local ADD_REVIEWER_ENTRY = "➕ Add a handle…"

--- Type handles the provider does not know: the only prompt the reviewer
--- picker's add-a-handle entry opens, never a fallback of its own.
---@param cb fun(handles: string[])
local function input_reviewers(cb)
	vim.ui.input({ prompt = "Reviewer handle(s), comma separated> " }, function(input)
		if not input then
			cb({})
			return
		end
		cb(reviewer_handles(input))
	end)
end

--- `br`: always a picker. Candidates come from the provider; when it cannot
--- list people the picker still opens (with the add-a-handle entry alone), so
--- the key never degrades into a bare prompt.
---@param buf integer
---@param opts table { provider }
local function pick_reviewers(buf, opts)
	local provider = opts.provider

	local function mark(handles)
		if not handles or #handles == 0 then
			return
		end
		vim.ui.select({ "Optional", "Required" }, { prompt = "These reviewers are" }, function(choice)
			add_reviewers(buf, handles, choice == "Required" and "required" or "optional")
		end)
	end

	--- Multi-select the candidates plus the manual entry, then mark the picked people.
	---@param entries string[]
	local function pick(entries)
		local menu = {}
		vim.list_extend(menu, entries or {})
		menu[#menu + 1] = ADD_REVIEWER_ENTRY
		pick_many(menu, { prompt = "Reviewers> " }, function(selected)
			local handles, wants_manual = {}, false
			for _, entry in ipairs(selected or {}) do
				if entry == ADD_REVIEWER_ENTRY then
					wants_manual = true
				elseif entry ~= "" then
					handles[#handles + 1] = entry
				end
			end
			if not wants_manual then
				mark(handles)
				return
			end
			-- The picker's own entry collects a handle the provider does not know.
			input_reviewers(function(typed)
				for _, handle in ipairs(typed) do
					if not vim.tbl_contains(handles, handle) then
						handles[#handles + 1] = handle
					end
				end
				mark(handles)
			end)
		end)
	end

	if not provider or type(provider.list_reviewers) ~= "function" then
		pick({})
		return
	end
	provider.list_reviewers(function(err, handles)
		vim.schedule(function()
			if err or not handles or #handles == 0 then
				-- No candidates (not authenticated, no permission): the picker still
				-- opens, so a handle can be added through its entry.
				vim.notify(
					"nvim-pr: could not list reviewers" .. (err and (": " .. err) or ""),
					vim.log.levels.WARN
				)
				pick({})
				return
			end
			pick(handles)
		end)
	end)
end

--- Open the Markdown draft. The PR is created only by `<C-c><C-c>`; `<C-c><C-k>`
--- and `:q!` close the buffer without doing anything.
---@param opts table create options (used to pre-fill the template)
---@param on_submit fun(fields: table)
function M.create(opts, on_submit)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, scratch_name())
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, template(opts))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"

	local function close()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end

	local function submit()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local parsed = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		if parsed.title == "" then
			-- Keeping the buffer open lets the user fix the draft and submit again.
			vim.notify("nvim-pr: write a title under `## Title` first", vim.log.levels.ERROR)
			return
		end
		local reviewers = {}
		for _, row in ipairs(parsed.reviewers or {}) do
			reviewers[#reviewers + 1] = row.handle
		end
		close()
		on_submit({
			title = parsed.title,
			body = parsed.body,
			head = parsed.head or opts.head,
			base = parsed.base or opts.base,
			reviewers = reviewers,
		})
	end

	vim.keymap.set("n", "<C-c><C-c>", submit, {
		buffer = buf,
		nowait = true,
		desc = "nvim-pr: create the pull request",
	})
	vim.keymap.set("n", "<C-c><C-k>", close, {
		buffer = buf,
		nowait = true,
		desc = "nvim-pr: discard the pull request draft",
	})
	vim.keymap.set("n", "bt", function()
		local parsed = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		M.pick_branch("base", parsed.base or opts.base, function(branch)
			set_target(buf, "base", branch)
			refresh_stat(buf)
		end)
	end, { buffer = buf, nowait = true, desc = "nvim-pr: pick the target branch (right side: where it will merge)" })
	vim.keymap.set("n", "bc", function()
		local parsed = M.parse(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		M.pick_branch("head", parsed.head or opts.head, function(branch)
			set_target(buf, "head", branch)
			refresh_stat(buf)
		end)
	end, { buffer = buf, nowait = true, desc = "nvim-pr: pick the source branch (left side: the one merged)" })
	vim.keymap.set("n", "br", function()
		pick_reviewers(buf, opts)
	end, { buffer = buf, nowait = true, desc = "nvim-pr: pick reviewers for the table" })
	vim.keymap.set("n", "<Tab>", function()
		-- Tab is only about the summary and its list: anywhere else it keeps its
		-- usual meaning.
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local current = lines[row] or ""
		if commit_row(current) then
			toggle_files(buf, row)
			return
		end
		if file_row(current) then
			-- Tab on a file row closes the commit that owns it.
			for index = row - 1, 1, -1 do
				if commit_row(lines[index]) then
					toggle_files(buf, index)
					return
				end
			end
			return
		end
		local first, last = expand_range(lines)
		if first then
			-- The list starts right under the summary line, so closing it is the
			-- same Tab on that line.
			if row >= first - 1 and row <= last then
				toggle_commits(buf)
			end
			return
		end
		if row == diff_index(lines) then
			toggle_commits(buf)
		end
	end, { buffer = buf, nowait = true, desc = "nvim-pr: list the commits behind the summary" })

	vim.api.nvim_set_current_buf(buf)
	for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		if line:match("^##%s*Title%s*$") then
			vim.api.nvim_win_set_cursor(0, { index + 2, 0 })
			break
		end
	end

	-- The summary is informational: it fills in once git answers, and stays a
	-- placeholder (`… commits · … files changed`) when a branch is unknown.
	refresh_stat(buf)
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
