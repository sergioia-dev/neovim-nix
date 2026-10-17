-- Taskwarrior lists (:Task). The list opens in a bottom split at half the
-- screen, and reloads itself when another terminal writes to the database.
--
-- Reports, filters and Taskwarrior commands all go through :Task — anything
-- that reads (`:Task all`, `:Task +work`, `:Task 12`) is rendered in the split
-- and everything that writes (`:Task add …`, `:Task 1 done`, `:Task sync`) runs
-- headless and reports through a notification.
require("taskwarrior").setup({
	-- Report used when only filters or IDs are given: `:Task +work` reads
	-- `next +work`.
	default_report = "next",

	-- Height of the split, as a fraction of the editor or as an absolute size.
	-- `size` accepts a number of lines or a share of the editor as "50%", and
	-- wins over `height_ratio` when it is set.
	height_ratio = 0.3,
	-- size = "50%",

	-- Absolute path or name of the task binary. `task` comes from the user's
	-- PATH, which the Neovim wrapper keeps visible.
	-- task_cmd = "/home/sia/.nix-profile/bin/task",

	-- Verbs that are answered with "yes" instead of a closed stdin, because a
	-- headless invocation cannot serve an interactive prompt. `undo` is the one
	-- command in day-to-day use that asks for confirmation.
	auto_yes = { "undo" },

	-- Watch $TASKDATA (default ~/.task) and re-render when another terminal or
	-- `task sync` changes the database. `r` reloads by hand either way.
	watch = true,

	close_on_focus_lost = true,
})
