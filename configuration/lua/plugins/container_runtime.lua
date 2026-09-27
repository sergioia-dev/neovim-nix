-- ~/.config/nvim/lua/container_runtime.lua
--
-- Container discovery + control without requiring `podman`/`docker` on PATH.
--
-- Tier 3: HTTP over the runtime's Unix socket (libuv pipe, no curl).
-- Tier 4: Reconstruct container list from /proc/<pid>/cgroup + runtime state dirs.
--
-- detect() picks socket if available, else falls back to /proc.
-- list() returns { { id, name, image, state, pids, ports }, ... }
-- stop(name_or_id) works only in socket mode; /proc mode refuses.

local M = {}

local uv = vim.uv or vim.loop

----------------------------------------------------------------------
-- Tier 3: HTTP/1.1 over a Unix socket
----------------------------------------------------------------------

local function socket_candidates()
	local uid = (vim.fn.system("id -u") or "1000"):gsub("%s+", "")
	local xdg = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. uid)
	return {
		{ path = xdg .. "/podman/podman.sock", api = "podman" },
		{ path = xdg .. "/docker.sock", api = "docker" },
		{ path = "/run/podman/podman.sock", api = "podman" },
		{ path = "/var/run/docker.sock", api = "docker" },
	}
end

-- Minimal sync HTTP client. Returns status_code, body (or nil, err).
local function http_over_unix(sock_path, method, path, body, timeout_ms)
	timeout_ms = timeout_ms or 3000
	local pipe = uv.new_pipe(false)
	local chunks = {}
	local done, err_msg = false, nil

	pipe:connect(sock_path, function(err)
		if err then
			err_msg = tostring(err)
			done = true
			return
		end

		local headers = {
			method .. " " .. path .. " HTTP/1.1",
			"Host: localhost",
			"Connection: close",
		}
		if body then
			table.insert(headers, "Content-Type: application/json")
			table.insert(headers, "Content-Length: " .. #body)
		end
		local req = table.concat(headers, "\r\n") .. "\r\n\r\n" .. (body or "")
		pipe:write(req)
	end)

	pipe:read_start(function(err, data)
		if err then
			err_msg = tostring(err)
			done = true
			return
		end
		if data then
			table.insert(chunks, data)
		else
			-- EOF: peer closed the connection
			done = true
			pcall(function()
				pipe:close()
			end)
		end
	end)

	vim.wait(timeout_ms, function()
		return done
	end)
	if not done then
		pcall(function()
			pipe:close()
		end)
		return nil, "timeout"
	end
	if err_msg then
		return nil, err_msg
	end

	local raw = table.concat(chunks)
	local status, rest = raw:match("^HTTP/%d%.%d%s+(%d+)[^\r\n]*\r\n(.*)$")
	if not status then
		return nil, "malformed response"
	end

	local header_block, body_block = rest:match("^(.-)\r\n\r\n(.*)$")
	if not header_block then
		return tonumber(status), ""
	end

	local len = tonumber(header_block:match("[Cc]ontent%-[Ll]ength:%s*(%d+)"))
	if len then
		return tonumber(status), body_block:sub(1, len)
	end

	if header_block:lower():find("transfer%-encoding:%s*chunked") then
		local decoded, pos = {}, 1
		while pos <= #body_block do
			local size_hex, after = body_block:match("^(%x+)\r\n()", pos)
			if not size_hex then
				break
			end
			local size = tonumber(size_hex, 16)
			if size == 0 then
				break
			end
			table.insert(decoded, body_block:sub(after, after + size - 1))
			pos = after + size + 2
		end
		return tonumber(status), table.concat(decoded)
	end

	return tonumber(status), body_block
end

----------------------------------------------------------------------
-- Tier 4: /proc cgroup walk + runtime state dirs
----------------------------------------------------------------------

-- PID → container ID via cgroup path. Handles cgroup v1 and v2.
local function pid_to_container_id(pid)
	local path = "/proc/" .. pid .. "/cgroup"
	if vim.fn.filereadable(path) == 0 then
		return nil
	end
	local lines = vim.fn.readfile(path)
	for _, line in ipairs(lines) do
		local id = line:match("libpod%-(%w+)%.scope")
			or line:match("docker%-(%w+)%.scope")
			or line:match("cri%-containerd%-(%w+)%.scope")
			or line:match("crio%-(%w+)%.scope")
		if id then
			return id
		end
	end
	return nil
end

local function runtime_state_dirs()
	local uid = (vim.fn.system("id -u") or "1000"):gsub("%s+", "")
	local xdg = os.getenv("XDG_RUNTIME_DIR") or ("/run/user/" .. uid)
	return {
		xdg .. "/containers/overlay-containers",
		xdg .. "/containers/storage/overlay-containers",
		"/run/containers/storage/overlay-containers",
	}
end

local function read_config(id)
	for _, base in ipairs(runtime_state_dirs()) do
		local cfg = base .. "/" .. id .. "/userdata/config.json"
		if vim.fn.filereadable(cfg) == 1 then
			local raw = table.concat(vim.fn.readfile(cfg), "")
			local ok, obj = pcall(vim.json.decode, raw)
			if ok and type(obj) == "table" then
				return obj
			end
		end
	end
	return nil
end

-- Full container id → short id used by podman ps (first 12 chars).
local function short_id(id)
	return id:sub(1, 12)
end

local function list_from_proc()
	local ids = {}

	for _, pid in ipairs(vim.fn.glob("/proc/[0-9]*", false, true)) do
		local p = pid:match("/(%d+)$")
		if p then
			local cid = pid_to_container_id(p)
			if cid then
				ids[cid] = ids[cid] or { pids = {} }
				table.insert(ids[cid].pids, tonumber(p))
			end
		end
	end

	local out = {}
	for id, info in pairs(ids) do
		local cfg = read_config(id)
		table.insert(out, {
			id = id,
			name = cfg and cfg.name or short_id(id),
			image = cfg and (cfg.rootfsImageName or cfg.image or "") or "",
			state = "running",
			status = "running",
			pids = info.pids,
			ports = {}, -- see caveat in the notes
		})
	end
	return out
end

----------------------------------------------------------------------
-- Socket API wrappers
----------------------------------------------------------------------

local function list_from_socket(rt)
	local path = rt.api == "podman" and "/v4.0.0/libpod/containers/json?all=true" or "/containers/json?all=true"

	local status, body = http_over_unix(rt.path, "GET", path)
	if status ~= 200 then
		return nil, body or ("HTTP " .. tostring(status))
	end

	local ok, list = pcall(vim.json.decode, body)
	if not ok or type(list) ~= "table" then
		return nil, "bad JSON"
	end

	return vim.tbl_map(function(c)
		local names = c.Names or c.name or {}
		local name = names[1] or c.Name or c.name or ""
		return {
			id = c.Id or c.ID or "",
			name = name:gsub("^/", ""),
			image = c.Image or c.image or "",
			state = c.State or c.state or "",
			status = c.Status or c.status or "",
			ports = c.Ports or {},
		}
	end, list)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

local _detected

function M.detect()
	if _detected then
		return _detected
	end

	for _, c in ipairs(socket_candidates()) do
		if vim.fn.getftype(c.path) == "socket" then
			local ping = c.api == "podman" and "/v4.0.0/libpod/_ping" or "/_ping"
			local status = http_over_unix(c.path, "GET", ping, nil, 1000)
			if status == 200 then
				_detected = { kind = "socket", api = c.api, path = c.path }
				return _detected
			end
		end
	end

	_detected = { kind = "proc" }
	return _detected
end

function M.reset()
	_detected = nil
end

function M.list()
	local rt = M.detect()

	if rt.kind == "socket" then
		local list, err = list_from_socket(rt)
		if list then
			return list
		end
		-- Socket went bad — fall through to /proc
		vim.notify("container_runtime: socket list failed: " .. tostring(err), vim.log.levels.WARN)
		_detected = { kind = "proc" }
	end

	return list_from_proc()
end

-- Returns true on success, or false + reason.
function M.stop(name_or_id)
	local rt = M.detect()

	if rt.kind == "socket" then
		local path = rt.api == "podman" and ("/v4.0.0/libpod/containers/" .. name_or_id .. "/stop")
			or ("/containers/" .. name_or_id .. "/stop")
		local status = http_over_unix(rt.path, "POST", path, "{}", 15000)
		if status == 204 or status == 200 or status == 304 then
			return true
		end
		return false, "HTTP " .. tostring(status)
	end

	return false, "no runtime socket; /proc mode cannot stop containers"
end

return M
