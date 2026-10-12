-- vim-dadbod UI configuration
vim.g.db_ui_use_nerdtree_to_toggle = 1
vim.g.db_ui_win_position = "right"

-- vim-dadbod-manager stores its connections - and the credentials they hold -
-- under the Neovim cache directory, one folder per app name: stdpath("cache")
-- is ~/.cache/<NVIM_APPNAME>, so with NVIM_APPNAME=nvim-custom (see neovim.nix)
-- this is ~/.cache/nvim-custom/vim-dadbod-manager/connections.json
local connections_dir = vim.fn.stdpath("cache") .. "/vim-dadbod-manager"
vim.fn.mkdir(connections_dir, "p")
vim.g.db_ui_save_location = connections_dir
