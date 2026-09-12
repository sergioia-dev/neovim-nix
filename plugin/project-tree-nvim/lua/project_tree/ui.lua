local M = {}

local config = require("project_tree.config")

-- Window state stored in module table for access from init.lua
M.window_id = nil
M.buffer_id = nil

-- Find the nearest project root by looking for common project markers.
local function find_project_root()
	local current_dir = vim.uv.cwd()
	if not current_dir or current_dir == "" then
		return vim.uv.cwd() or vim.fn.getcwd()
	end

	while current_dir and current_dir ~= "" do
		for _, marker in ipairs({ ".git", ".hg", "flake.nix" }) do
			if vim.fn.isdirectory(current_dir .. "/" .. marker) == 1 then
				return current_dir
			end
		end

		local parent = current_dir:match("^(.*)/[^/]*$")
		if parent == nil or parent == current_dir then
			break
		end
		current_dir = parent
	end

	return vim.uv.cwd() or vim.fn.getcwd()
end

-- Build the complete tree command from the current option state.
local function build_tree_command()
	local state = config.get()
	local args = { "tree" }

	if state.gitignore then
		table.insert(args, "--gitignore")
	end
	if state.hidden then
		table.insert(args, "-a")
	end
	if state.dirs_only then
		table.insert(args, "-d")
	end
	if state.human_size then
		table.insert(args, "-h")
	end
	if state.dirsfirst then
		table.insert(args, "--dirsfirst")
	end
	if state.permissions then
		table.insert(args, "-p")
	end
	if state.depth > 0 then
		table.insert(args, "-L")
		table.insert(args, tostring(state.depth))
	end
	if state.prune then
		table.insert(args, "--prune")
	end

	table.insert(args, find_project_root())
	return args
end

-- Create a compact legend showing every option and its current state.
local function build_legend()
	local state = config.get()
	local lines = { "[ Project Tree ]" }
	table.insert(lines, "g:" .. (state.gitignore and "ON" or "OFF"))
	table.insert(lines, "a:" .. (state.hidden and "ON" or "OFF"))
	table.insert(lines, "d:" .. (state.dirs_only and "ON" or "OFF"))
	table.insert(lines, "s:" .. (state.human_size and "ON" or "OFF"))
	table.insert(lines, "r:" .. (state.dirsfirst and "ON" or "OFF"))
	table.insert(lines, "p:" .. (state.permissions and "ON" or "OFF"))
	table.insert(lines, "L:" .. (state.depth > 0 and tostring(state.depth) or "all"))
	table.insert(lines, "P:" .. (state.prune and "ON" or "OFF"))
	table.insert(lines, "| q/Esc=close R=refresh")
	return table.concat(lines, " ")
end

-- Split tree output into buffer lines.
local function split_lines(output)
	if output == nil or output == "" then
		return { "" }
	end

	local lines = {}
	for line in output:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end
	if #lines == 0 then
		table.insert(lines, "")
	end
	return lines
end

-- Run tree and collect its stdout/stderr.
local function run_tree()
	local command = build_tree_command()
	vim.system(command, { text = true }, function(output)
		vim.schedule(function()
			if M.window_id == nil or not vim.api.nvim_win_is_valid(M.window_id) then
				return
			end

			local content = output.stdout or ""
			local exit_code = output.code

			if exit_code ~= 0 then
				content = "tree exited with code " .. tostring(exit_code) .. "\n\n" .. (output.stderr or "")
			end

			local lines = split_lines(content)
			table.insert(lines, 1, build_legend())
			table.insert(lines, 2, "")

			vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, lines)
			vim.api.nvim_set_option_value("buftype", "nofile", { buf = M.buffer_id })
			vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = M.buffer_id })
			vim.api.nvim_set_option_value("swapfile", false, { buf = M.buffer_id })
			vim.api.nvim_set_option_value("modifiable", false, { buf = M.buffer_id })
		end)
	end)
end

-- Set up all keymaps local to the floating window buffer.
local function set_window_keymaps()
	local function map(mode, lhs, rhs, opts)
		local options = opts or {}
		options.buffer = M.buffer_id
		vim.keymap.set(mode, lhs, rhs, options)
	end

	map("n", "q", function()
		M.close()
	end, { desc = "Close project tree", silent = true })
	map("n", "<Esc>", function()
		M.close()
	end, { desc = "Close project tree", silent = true })
	map("n", "g", function()
		config.set("gitignore", not config.get().gitignore)
		M.refresh()
	end, { desc = "Toggle gitignore", silent = true })
	map("n", "a", function()
		config.set("hidden", not config.get().hidden)
		M.refresh()
	end, { desc = "Toggle hidden files", silent = true })
	map("n", "d", function()
		config.set("dirs_only", not config.get().dirs_only)
		M.refresh()
	end, { desc = "Toggle directories only", silent = true })
	map("n", "s", function()
		config.set("human_size", not config.get().human_size)
		M.refresh()
	end, { desc = "Toggle human-readable sizes", silent = true })
	map("n", "r", function()
		config.set("dirsfirst", not config.get().dirsfirst)
		M.refresh()
	end, { desc = "Toggle directories first", silent = true })
	map("n", "p", function()
		config.set("permissions", not config.get().permissions)
		M.refresh()
	end, { desc = "Toggle permissions", silent = true })
	map("n", "L", function()
		config.cycle_depth()
		M.refresh()
	end, { desc = "Cycle tree depth", silent = true })
	map("n", "P", function()
		config.set("prune", not config.get().prune)
		M.refresh()
	end, { desc = "Toggle prune", silent = true })
	map("n", "R", function()
		M.refresh()
	end, { desc = "Refresh project tree", silent = true })
	map("n", "<C-f>", function()
		vim.api.nvim_win_set_cursor(M.window_id, vim.api.nvim_win_get_cursor(M.window_id) + 1)
	end, { desc = "Scroll down", silent = true })
	map("n", "<C-b>", function()
		vim.api.nvim_win_set_cursor(M.window_id, vim.api.nvim_win_get_cursor(M.window_id) - 1)
	end, { desc = "Scroll up", silent = true })
end

-- Open the floating window and prepare its buffer.
function M.open()
	if M.window_id ~= nil and vim.api.nvim_win_is_valid(M.window_id) then
		vim.api.nvim_set_current_win(M.window_id)
		return
	end

	M.buffer_id = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, { build_legend(), "" })

	local width = math.floor(vim.o.columns * 0.85)
	local height = math.floor(vim.o.lines * 0.80)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	M.window_id = vim.api.nvim_open_win(M.buffer_id, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_win_set_option(M.window_id, "wrap", false)
	vim.api.nvim_win_set_option(M.window_id, "cursorline", false)
	vim.api.nvim_win_set_option(M.window_id, "number", false)
	vim.api.nvim_win_set_option(M.window_id, "relativenumber", false)
	vim.api.nvim_win_set_option(M.window_id, "foldenable", false)

	set_window_keymaps()
end

-- Run tree and update the existing floating window.
function M.refresh()
	if M.window_id == nil or not vim.api.nvim_win_is_valid(M.window_id) then
		vim.notify("Project tree is not open", vim.log.levels.WARN)
		return
	end

	vim.api.nvim_set_current_win(M.window_id)
	vim.api.nvim_set_option_value("modifiable", true, { buf = M.buffer_id })
	vim.api.nvim_buf_set_lines(M.buffer_id, 0, -1, false, { build_legend(), "" })
	run_tree()
end

-- Close the floating window and release its resources.
function M.close()
	if M.window_id ~= nil and vim.api.nvim_win_is_valid(M.window_id) then
		vim.api.nvim_win_close(M.window_id, true)
	end

	M.window_id = nil
	M.buffer_id = nil
end

-- Toggle a single option and refresh the window.
function M.toggle_flag(key)
	if config.get()[key] == nil then
		return
	end

	local new_value = not config.get()[key]
	config.set(key, new_value)

	if M.window_id ~= nil and vim.api.nvim_win_is_valid(M.window_id) then
		M.refresh()
	end
end

-- Cycle the depth level and refresh the window.
function M.cycle_depth()
	config.cycle_depth()

	if M.window_id ~= nil and vim.api.nvim_win_is_valid(M.window_id) then
		M.refresh()
	end
end

return M