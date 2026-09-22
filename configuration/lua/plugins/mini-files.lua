local M = {}

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Replace the built-in file explorer with mini.files
require("mini.files").setup({
  options = {
    -- Use mini.files as the default file explorer
    use_as_default_explorer = true,
    -- Move deleted files to trash instead of permanent delete
    permanent_delete = false,
  },
  windows = {
    -- Preview file/directory under cursor
    preview = true,
    width_focus = 40,
    width_nofocus = 12,
    width_preview = 25,
  },
})

-- Toggle the mini.files explorer (open or close).
-- Uses the combination of MiniFiles.close() and MiniFiles.open().
function M.minifiles_toggle(...)
  if MiniFiles.close() == nil then
    MiniFiles.open(...)
  end
end

-- Open mini.files at the right side of the screen.
-- mini.files uses floating windows, so right-align them via the
-- MiniFilesWindowOpen event (large col is clamped to the right edge).
vim.api.nvim_create_autocmd("User", {
  pattern = "MiniFilesWindowOpen",
  callback = function(args)
    local win_id = args.data.win_id
    local config = vim.api.nvim_win_get_config(win_id)
    config.col = math.huge
    vim.api.nvim_win_set_config(win_id, config)
  end,
})

return M