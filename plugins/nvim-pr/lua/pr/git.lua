--- Read-only git helpers. Everything here answers "which branch is which"; the
--- providers do the writing (create, merge, checkout) through their CLIs.
local M = {}

local DEFAULT_REMOTE = "origin"

---@type table<string, string|false>
local default_cache = {}

---@type table<string, boolean>|nil
local remote_cache = nil

--- Run `git` (pinned to the repository root) and return its stdout lines.
---@param args string[]
---@param timeout integer|nil milliseconds, defaults to 5000
---@return string[]|nil lines nil when git is missing, times out or exits non-zero
local function run(args, timeout)
	local command = { "git" }
	local root = require("pr.detect").root()
	if root then
		vim.list_extend(command, { "-C", root })
	end
	vim.list_extend(command, args)
	local ok, result = pcall(function()
		return vim.system(command, { text = true }):wait(timeout or 5000)
	end)
	if not ok or not result or result.code ~= 0 then
		return nil
	end
	return vim.split(result.stdout or "", "\n", { trimempty = true })
end

--- Collect unique, sorted branch names from one `for-each-ref` listing.
---@param lines string[]|nil
---@return string[] Names as git reports them, `origin/` prefix included.
local function collect(lines)
	local branches, seen = {}, {}
	for _, line in ipairs(lines or {}) do
		local name = vim.trim(line)
		if name ~= "" and name ~= "HEAD" and name ~= "origin" and not name:match("/HEAD$") and not seen[name] then
			seen[name] = true
			branches[#branches + 1] = name
		end
	end
	table.sort(branches)
	return branches
end

--- The branch HEAD points at, or nil when detached / not a repository.
---@return string|nil
function M.current_branch()
	local out = run({ "rev-parse", "--abbrev-ref", "HEAD" })
	local branch = out and vim.trim(out[1] or "") or ""
	if branch == "" or branch == "HEAD" then
		-- A repository with no commits yet has an unborn HEAD, which
		-- `rev-parse` rejects; `symbolic-ref` still names the branch.
		branch = vim.trim((run({ "symbolic-ref", "--short", "HEAD" }) or {})[1] or "")
	end
	if branch == "" or branch == "HEAD" then
		return nil
	end
	return branch
end

--- Branches that exist locally (what `bc` picks from).
---@return string[]
function M.local_branches()
	local out = run({ "for-each-ref", "--format=%(refname:short)", "refs/heads/" })
	local branches = collect(out)
	if #branches == 0 then
		branches = collect(run({ "branch", "--format=%(refname:short)" }))
	end
	return branches
end

--- Branches that exist on `remote`, asked from the remote itself (what `bt`
--- picks from). The remote is queried live, so a stale clone that was never
--- fetched still shows every branch; when the remote is unreachable the
--- remote-tracking refs are used instead.
---@param remote string|nil
---@return string[]
function M.remote_branches(remote)
	remote = remote or DEFAULT_REMOTE
	local live, seen = {}, {}
	for _, line in ipairs(run({ "ls-remote", "--heads", remote }, 8000) or {}) do
		local name = line:match("refs/heads/(%S+)$")
		if name and name ~= "HEAD" and not seen[name] then
			seen[name] = true
			-- Keep the `origin/` prefix: the picker lists remote branches, so it
			-- must be obvious where they live without opening `git branch -r`.
			live[#live + 1] = remote .. "/" .. name
		end
	end
	if #live > 0 then
		table.sort(live)
		return live
	end

	local branches = collect(
		run({ "for-each-ref", "--format=%(refname:short)", ("refs/remotes/%s/"):format(remote) })
	)
	if #branches == 0 then
		branches = collect(run({ "branch", "-r", "--format=%(refname:short)" }))
	end
	return branches
end

--- The remote's default branch: what `origin/HEAD` advertised last fetch, or the
--- authoritative answer straight from the remote. Falls back to main/master.
---@param remote string|nil
---@return string|nil
function M.default_branch(remote)
	remote = remote or DEFAULT_REMOTE
	local cached = default_cache[remote]
	if cached ~= nil then
		return cached or nil
	end

	local name
	-- Ask the remote itself: correct even in a clone that never fetched.
	for _, line in ipairs(run({ "ls-remote", "--symref", remote, "HEAD" }, 8000) or {}) do
		name = line:match("^ref:%s+refs/heads/(%S+)%s+HEAD$")
		if name then
			break
		end
	end

	if not name then
		local sym = run({ "symbolic-ref", "--short", ("refs/remotes/%s/HEAD"):format(remote) })
		if sym and sym[1] then
			name = vim.trim(sym[1]):gsub("^" .. vim.pesc(remote) .. "/", "")
		end
	end

	if not name or name == "" then
		local known = {}
		for _, branch in ipairs(M.remote_branches(remote)) do
			-- Remote branches carry the `origin/` prefix; the candidates below
			-- are bare names, so store both spellings.
			known[branch] = true
			known[(branch:gsub("^" .. vim.pesc(remote) .. "/", ""))] = true
		end
		for _, branch in ipairs(M.local_branches()) do
			known[branch] = true
		end
		for _, candidate in ipairs({ "main", "master" }) do
			if known[candidate] then
				name = candidate
				break
			end
		end
	end

	default_cache[remote] = name or false
	return name
end

--- Forget cached repository data (called when the working directory changes).
--- Run `git` in the background and hand its stdout lines to `cb`.
---@param args string[]
---@param cb fun(lines: string[]|nil) nil when git exits non-zero
local function run_async(args, cb)
	local command = { "git" }
	local root = require("pr.detect").root()
	if root then
		vim.list_extend(command, { "-C", root })
	end
	vim.list_extend(command, args)
	local ok = pcall(vim.system, command, { text = true }, function(result)
		vim.schedule(function()
			if not result or result.code ~= 0 then
				return cb(nil)
			end
			cb(vim.split(result.stdout or "", "\n", { trimempty = true }))
		end)
	end)
	if not ok then
		cb(nil)
	end
end

--- Remote names, so `origin/topic` is told apart from a local `team/topic`.
---@return table<string, boolean>
local function remotes()
	if remote_cache then
		return remote_cache
	end
	remote_cache = {}
	for _, line in ipairs(run({ "remote" }) or {}) do
		local name = vim.trim(line)
		if name ~= "" then
			remote_cache[name] = true
		end
	end
	return remote_cache
end

--- The commit the remote itself reports for a branch, used when the branch was
--- never fetched: `bt` lists branches asked straight from the remote, so its
--- picks often have no local ref to walk. Only a commit that is already in the
--- object database is accepted, so this never fetches behind the user's back.
---@param remote string
---@param branch string
---@param cb fun(ref: string|nil)
local function remote_tip(remote, branch, cb)
	run_async({ "ls-remote", "--heads", remote, ("refs/heads/%s"):format(branch) }, function(lines)
		local sha = lines and lines[1] and lines[1]:match("^(%x+)")
		if not sha then
			return cb(nil)
		end
		run_async({ "rev-parse", "--verify", "--quiet", sha .. "^{commit}" }, function(verified)
			cb(verified and verified[1] ~= nil and sha or nil)
		end)
	end)
end

--- Accept a branch name git can actually walk: the local ref, else its
--- remote-tracking counterpart (a fresh clone often has only the latter), else
--- the commit the remote reports for it.
---@param name string
---@param cb fun(ref: string|nil)
local function resolve_ref(name, cb)
	local candidates = { name, DEFAULT_REMOTE .. "/" .. name }
	local prefix, rest = name:match("^([%w._-]+)/(.+)$")
	local remote, branch = DEFAULT_REMOTE, name
	if prefix and remotes()[prefix] then
		remote, branch = prefix, rest
	end
	local index = 1
	local function attempt()
		local candidate = candidates[index]
		index = index + 1
		if not candidate then
			return remote_tip(remote, branch, cb)
		end
		run_async({ "rev-parse", "--verify", "--quiet", candidate .. "^{commit}" }, function(lines)
			if lines and lines[1] and lines[1] ~= "" then
				cb(candidate)
			else
				attempt()
			end
		end)
	end
	attempt()
end

--- How much a pull request from `head` into `base` would move: the commits it
--- adds and the files it touches. Both come from the merge base
--- (`base...head`), so work base already has is not counted twice.
---@param head string|nil source branch
---@param base string|nil target branch
---@param cb fun(stats: { commits: integer, files: integer }|nil) nil when a branch is unknown, unpushed or unreadable
function M.diff_stat(head, base, cb)
	if not head or head == "" or not base or base == "" then
		return cb(nil)
	end
	resolve_ref(base, function(base_ref)
		if not base_ref then
			return cb(nil)
		end
		resolve_ref(head, function(head_ref)
			if not head_ref then
				return cb(nil)
			end
			run_async({ "rev-list", "--count", ("%s..%s"):format(base_ref, head_ref) }, function(counts)
				local commits = tonumber(counts and counts[1] or "")
				if not commits then
					return cb(nil)
				end
				run_async({ "diff", "--name-only", ("%s...%s"):format(base_ref, head_ref) }, function(files)
					if not files then
						return cb(nil)
					end
					cb({ commits = commits, files = #files })
				end)
			end)
		end)
	end)
end

--- The commits the draft would add, each with the files it touches: what the
--- diff summary counts, spelled out one commit at a time.
---@param head string|nil source branch
---@param base string|nil target branch
---@param cb fun(commits: { sha: string, subject: string, files: string[] }[]|nil)
function M.changes(head, base, cb)
	if not head or head == "" or not base or base == "" then
		return cb(nil)
	end
	resolve_ref(base, function(base_ref)
		if not base_ref then
			return cb(nil)
		end
		resolve_ref(head, function(head_ref)
			if not head_ref then
				return cb(nil)
			end
			-- One call: `log --name-only` puts each commit's files under it. The
			-- \1 marker keeps a commit line apart from a file that looks like one.
			run_async(
				{ "log", "--no-merges", "--name-only", "--format=\1%h %s", ("%s..%s"):format(base_ref, head_ref) },
				function(lines)
					if not lines then
						return cb(nil)
					end
					local commits, current = {}, nil
					for _, line in ipairs(lines) do
						local sha, subject = line:match("^\1(%S+) (.*)$")
						if sha then
							current = { sha = sha, subject = subject, files = {} }
							commits[#commits + 1] = current
						elseif current then
							local file = vim.trim(line)
							if file ~= "" then
								current.files[#current.files + 1] = file
							end
						end
					end
					cb(commits)
				end
			)
		end)
	end)
end

function M.reset()
	default_cache = {}
	remote_cache = nil
end

return M
