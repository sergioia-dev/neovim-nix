local M = {}

local config = require("pr.config")
local detect = require("pr.detect")
local providers = require("pr.providers")

--- Minimum versions the flag/JSON contract was written against.
local MINIMUM = { github = "2.0", gitlab = "1.30", azure = "2.30" }

local CLIS = { github = "gh", gitlab = "glab", azure = "az" }

local AUTH = {
	github = { "auth", "status" },
	gitlab = { "auth", "status" },
	azure = { "account", "show" },
}

--- Run a command and return its trimmed output ("" when it fails).
local function capture(cmd, timeout)
	local ok, result = pcall(function()
		return vim.system(cmd, { text = true }):wait(timeout or 5000)
	end)
	if not ok or not result then
		return "", -1
	end
	local output = (result.stdout or "") .. (result.stderr or "")
	return vim.trim(output), result.code or -1
end

--- First `x.y` or `x.y.z` in a version string.
local function version_of(text)
	local major, minor = text:match("(%d+)%.(%d+)")
	if not major then
		return nil
	end
	return tonumber(major) + tonumber(minor) / 1000
end

local function check_cli(health, name)
	local cli = CLIS[name]
	health.start(("%s CLI (%s)"):format(name, cli))

	if vim.fn.executable(cli) ~= 1 then
		health.error(("`%s` is not on PATH; nvim-pr cannot talk to %s"):format(cli, name), {
			("Add %s to the wrapper's runtimeDependencies or to the dev shell (see shell.nix)"):format(cli),
		})
		return
	end

	local version_output, code = capture({ cli, "--version" })
	if code ~= 0 then
		health.warn(("`%s --version` failed"):format(cli), { version_output })
	else
		local found = version_of(version_output)
		local minimum = MINIMUM[name]
		if found and minimum and found < version_of(minimum) then
			health.warn(("`%s` is older than the %s minimum nvim-pr is written against"):format(cli, minimum), {
				(version_output:gsub("\n", " ")),
			})
		else
			health.ok(("%s is installed"):format((version_output:gsub("\n.*$", ""))))
		end
	end

	local auth_output, auth_code = capture(vim.list_extend({ cli }, AUTH[name]))
	if auth_code == 0 then
		health.ok(("%s is authenticated"):format(cli))
	else
		health.warn(
			("%s does not look authenticated; run `%s` outside Neovim"):format(
				cli,
				table.concat({ cli, unpack(AUTH[name]) }, " ")
			),
			{
				auth_output,
			}
		)
	end
end

function M.check()
	-- `health` is a local alias so the file also works when run directly.
	local health = vim.health
	local cfg = config.get()

	health.start("nvim-pr")

	local root = detect.root()
	if root then
		health.ok(("repository root is %s"):format(root))
	else
		health.warn(
			"the working directory is not inside a git repository; commands would run against whatever the CLIs find"
		)
	end

	local remote = detect.remote_url()
	if not remote then
		health.warn("no git remote named `origin`; provider detection cannot work here")
	else
		health.ok(("origin is %s"):format(remote))
	end

	local detected, host = detect.name(remote, cfg)
	if detected then
		health.ok(("detected provider: %s (%s)"):format(detected, host or "?"))
	elseif remote then
		health.warn("could not map the origin host to a provider", {
			'Set `default_provider` in `require("pr").setup({})` to override detection.',
		})
	end

	if cfg.default_provider then
		health.info(("configured default_provider: %s"):format(cfg.default_provider))
	end

	if detected == "azure" and remote then
		local context = detect.azure_context(remote)
		if context then
			health.info(
				("azure organization=%s project=%s repository=%s"):format(
					context.organization,
					context.project,
					context.repository
				)
			)
		else
			health.warn(("could not read organization/project/repository from %s"):format(remote), {
				"Azure calls fall back to `az devops configure` defaults.",
			})
		end
	end

	health.start("CLIs")
	for _, name in ipairs(providers.names()) do
		if (cfg.providers or {})[name] and cfg.providers[name].enabled ~= false then
			check_cli(health, name)
		end
	end
end

return M
