local M = {}

-- `pr.providers` is a registry: init.lua asks for a provider by name, the
-- providers themselves are loaded lazily so a missing CLI never breaks startup.
local modules = {
	github = "pr.providers.github",
	gitlab = "pr.providers.gitlab",
	azure = "pr.providers.azure",
}

---@class PRItem
---@field id string
---@field number integer|nil
---@field title string
---@field url string|nil
---@field author string|nil
---@field state string|nil
---@field base_branch string|nil
---@field head_branch string|nil
---@field draft boolean|nil
---@field created_at string|nil
---@field updated_at string|nil
---@field body string|nil

---@class PRProvider
---@field name string
---@field cli string
---@field is_available fun(): boolean
---@field create fun(opts: table, cb: fun(err?: string, url?: string))
---@field list fun(opts: table, cb: fun(err?: string, items?: PRItem[]))
---@field view fun(id: string|nil, cb: fun(err?: string, detail?: table))
---@field checkout fun(id: string, cb: fun(err?: string))
---@field merge fun(id: string, opts: table, cb: fun(err?: string))
---@field open_browser fun(id: string|nil, cb: fun(err?: string))

---@param name string
---@return PRProvider|nil
function M.get(name)
	local module = modules[name]
	if not module then
		return nil
	end
	local ok, provider = pcall(require, module)
	if not ok then
		return nil
	end
	return provider
end

--- Names in a stable order.
---@return string[]
function M.names()
	return { "github", "gitlab", "azure" }
end

return M
