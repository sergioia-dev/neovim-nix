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

-- Return the window ID of a visible mini.files explorer window, or nil.
-- Explorer buffers use filetype 'minifiles' (and 'minifiles-help' for the help
-- overlay). Detecting by filetype is intentional: it mirrors how sidebars.lua
-- detects the DadBod UI via its 'dbui' filetype and does not depend on any
-- optional MiniFiles state API.
local function get_minifiles_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
    if ft == "minifiles" or ft == "minifiles-help" then
      return win
    end
  end
  return nil
end

-- Return true when the mini.files explorer window is visible.
function M.minifiles_is_open()
  return get_minifiles_window() ~= nil
end

-- Close mini.files if it is open. Safe to call unconditionally, and unlike
-- minifiles_toggle() it never opens the explorer.
-- Returns true if an explorer was closed, false if it was already closed or
-- the user declined to close with pending filesystem actions.
function M.minifiles_close()
  return MiniFiles.close() == true
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