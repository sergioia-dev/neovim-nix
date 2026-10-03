-- Terminal sidebars (right: <C-w>%, bottom: <C-w>").
--
-- A terminal closes as soon as it loses focus, but its buffer is cached, so the
-- shell session and its scrollback survive and the next toggle restores the same
-- terminal.
require("toggable_term").setup({
	close_on_focus_loss = true,

	-- Start a program in a terminal the first time it is created, then reuse that
	-- session on every later toggle:
	vertical_init = "pi",
	-- horizontal_init = nil,
	-- float_init = nil,

	-- Size of a terminal: a number of cells, or a share of the editor as
	-- "30%". These win over the ratio options (width_ratio, height_ratio,
	-- float_width_ratio, float_height_ratio), which stay the fallback:
	-- vertical_size = 30, -- 30 columns wide
	-- horizontal_size = 30, -- 30 lines tall
	-- float_width = 50, -- 50 columns wide
	-- float_height = 50, -- 50 lines tall
	-- Keep the sidebars of this configuration mutually exclusive: the terminals
	-- are closed by the plugin, DBUI and mini.files by plugins.sidebars.
	before_open = function()
		require("plugins.sidebars").close_other_sidebars()
	end,
})
