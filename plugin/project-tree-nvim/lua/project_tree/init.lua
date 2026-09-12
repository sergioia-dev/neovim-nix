local M = {}

local config = require("project_tree.config")
local ui = require("project_tree.ui")

-- Open or close the floating window (toggle behavior).
function M.toggle()
	if ui.window_id ~= nil and vim.api.nvim_win_is_valid(ui.window_id) then
		ui.close()
	else
		ui.open()
		ui.refresh()
	end
end

-- Refresh the floating window content if it is open.
function M.refresh()
	if ui.window_id == nil or not vim.api.nvim_win_is_valid(ui.window_id) then
		vim.notify("Project tree is not open", vim.log.levels.WARN)
		return
	end

	ui.refresh()
end

-- Toggle a single option and refresh the window.
function M.toggle_flag(key)
	if config.get()[key] == nil then
		return
	end

	local new_value = not config.get()[key]
	config.set(key, new_value)

	if ui.window_id ~= nil and vim.api.nvim_win_is_valid(ui.window_id) then
		M.refresh()
	end
end

-- Cycle the depth level and refresh the window.
function M.cycle_depth()
	config.cycle_depth()

	if ui.window_id ~= nil and vim.api.nvim_win_is_valid(ui.window_id) then
		M.refresh()
	end
end

-- Public API
M.setup = config.setup
M.open = ui.open
M.close = ui.close
M.toggle = M.toggle
M.refresh = M.refresh
M.toggle_flag = M.toggle_flag
M.cycle_depth = M.cycle_depth
M.config = config

return M