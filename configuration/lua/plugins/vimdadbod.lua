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

-- Backups land beside the connections, one folder per database: the plugin
-- appends a slug of the database name, so a backup of "shop" is written to
-- <cache>/vim-dadbod-manager/shop/. Setting the option to the connections
-- folder gives the layout the plugin cannot know on its own (its own default
-- is a flat ~/dbui-backups).
vim.g.dbui_multidb_backup_dir = connections_dir
