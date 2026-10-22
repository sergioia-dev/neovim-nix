-- Terminal sidebars (right: <C-w>%, bottom: <C-w>").
--
-- Every terminal kind closes as soon as it loses focus, but its buffer is cached,
-- so the shell session and its scrollback survive and the next toggle restores
-- the same terminal. Turn that off for one kind with, for example,
-- `float_close_on_focus_loss = false` (and `:TermFocusClose float off` at runtime).
require("toggable_term").setup({

	-- Start a program in a terminal the first time it is created, then reuse that
	-- session on every later toggle:
	vertical_init = "pi",
	-- Start it in the background instead, when the plugin is set up: the terminal
	-- is created hidden and `pi` is already running when it is first toggled, so
	-- the window opens on the program instead of a fresh shell:
	-- vertical_background_init = true,
	-- horizontal_init = nil,
	-- float_init = nil,

	-- Size of a terminal: a number of cells, or a share of the editor as
	-- "30%". These win over the ratio options (width_ratio, height_ratio,
	-- float_width_ratio, float_height_ratio), which stay the fallback:
	-- vertical_size = 30, -- 30 columns wide
	-- horizontal_size = 30, -- 30 lines tall
	-- float_width = 90, -- 50 columns wide
	-- float_height = 50, -- 50 lines tall
	vertical_close_on_focus_loss = true,
	horizontal_close_on_focus_loss = true,
	float_close_on_focus_loss = true,

	-- Line numbers inside a terminal window are explicit and off by default.
	-- `true` shows 'number' / 'relativenumber' in that kind's window, `false`
	-- also overrides a global 'number' / 'relativenumber', and both are applied
	-- on every open. The defaults are what this configuration uses.
	-- vertical_line_number = true,
	-- vertical_relative_line_number = true,
	-- horizontal_line_number = true,
	-- horizontal_relative_line_number = true,
	-- float_line_number = true,
	-- float_relative_line_number = true,
	-- Keep the sidebars of this configuration mutually exclusive: the terminals
	-- are closed by the plugin, DBUI and mini.files by plugins.sidebars.
	before_open = function()
		require("plugins.sidebars").close_other_sidebars()
	end,
})
