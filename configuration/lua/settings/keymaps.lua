vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set

-- Navigation
keymap("n", "<leader>fn", function()
	require("net_picker").setup({ telescope = false, fzf = true }).net_picker()
end, { desc = "Net picker (fzf-lua backend)" })

keymap("n", "<leader>ff", function()
	require("fzf-lua").files()
end, { desc = "Find files", silent = true })

keymap("n", "<leader>fc", ":TodoFzfLua<CR>", { desc = "Find Todo comments", silent = true })

keymap("n", "<leader>fa", function()
	require("fzf-lua").live_grep()
end, { desc = "Live grep", silent = true })

keymap({ "n", "v" }, "<leader><Tab>", function()
	require("fzf-lua").buffers()
end, { desc = "Live grep", silent = true })

keymap("n", "<leader>fi", function()
	require("fzf-lua").blines()
end, { desc = "Live grep in Current file", silent = true })

-- LSP
keymap(
	"n",
	"<leader>cr",
	"<cmd>:Lspsaga finder<CR>",
	{ desc = "Show the code references and Implementations", silent = true }
)

keymap("n", "<leader>cR", "<cmd>:Lspsaga rename<CR>", { desc = "Code References", silent = true })
keymap("n", "K", "<cmd>:Lspsaga hover_doc<CR>", { desc = "Documentation Hover", silent = true })
keymap("n", "<leader>co", "<cmd>:Lspsaga outline<CR>", { desc = "Code References", silent = true })
keymap("n", "<leader>cf", function()
	require("fzf-lua").treesitter()
end, { desc = "Find Functions,Variables and more", silent = true })
keymap("n", "<leader>ca", "<cmd>:Lspsaga code_action<CR>", { desc = "Code Actions", silent = true })
keymap("n", "<leader>ce", function()
	require("fzf-lua").diagnostics_workspace()
end, { desc = "Code Diagnostics", silent = true })
keymap("n", "<leader>cq", function()
	require("fzf-lua").quickfix()
end, { desc = "Quick Fix List", silent = true })
keymap(
	"n",
	"<leader>cs",
	"<cmd>:lua vim.diagnostic.open_float()<CR>",
	{ desc = "Show whole Code warning/error/suggestion", silent = true }
)
keymap("n", "<leader>ci", function()
	require("fzf-lua").lsp_implementations()
end, { desc = "Code Definitions", silent = true })

keymap({ "n", "v" }, "<leader>m", function()
	require("fzf-lua").marks()
end, { desc = "Save File", silent = true })

-- Git
keymap(
	"n",
	"<leader>glb",
	"<cmd>:Gitsigns toggle_current_line_blame<CR>",
	{ desc = "Toggle Line blames", silent = true }
)
keymap("n", "<leader>gg", "<cmd>:Neogit kind=replace<CR>", { desc = "Toggle Neogit Interface", silent = true })
keymap("n", "<leader>gb", function()
	require("fzf-lua").git_branches()
end, { desc = "Open a view with the git branches", silent = true })
keymap("n", "<leader>gc", function()
	require("fzf-lua").git_commits()
end, { desc = "Open a view with the git commits", silent = true })

-- Pi agent
keymap({ "n", "v" }, "<leader>pp", ":Pi<CR>")
keymap({ "n", "v" }, "<leader>ps", ":PiSessions<CR>")

keymap({ "n", "v" }, "<F1>", require("plugins.sidebars").toggle_dadbod, { desc = "Toggle DadBod UI", silent = true })

keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

keymap(
	{ "n", "v" },
	"<leader>tv",
	require("plugins.terminal").toggle_right_terminal,
	{ desc = "Toggle Right Terminal", silent = true }
)

keymap(
	{ "n", "v" },
	"<leader>fm",
	require("plugins.sidebars").toggle_minifiles,
	{ desc = "Toggle mini.files Explorer Sidebar", silent = true }
)

keymap(
	{ "n", "v" },
	"<leader>th",
	require("plugins.terminal").toggle_bottom_terminal,
	{ desc = "Toggle Bottom Terminal", silent = true }
)

keymap({ "n", "v" }, "<C-s>", ":w<CR>", { desc = "Save File", silent = true })

vim.keymap.del("n", "<leader>co") -- Remove Lspsaga's mapping
