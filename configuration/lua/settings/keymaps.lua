vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set

keymap("n", "<leader>ft", ":ProjectTree<CR>", { desc = "Toggle Project Tree", silent = true })

-- Navigation
keymap(
	{ "n", "t", "v" },
	"<leader>fm",
	require("plugins.sidebars").lexplore,
	{ desc = "Open Explorer / DBUI", silent = true }
)

keymap("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files", silent = true })

keymap("n", "<leader>fc", ":TodoTelescope<CR>", { desc = "Find Todo comments", silent = true })

keymap("n", "<leader>fs", ":Telescope persisted theme=dropdown<CR>", { desc = "Find saved sessions", silent = true })

keymap("n", "<leader>fa", ":Telescope live_grep theme=dropdown<CR>", { desc = "Live grep", silent = true })

keymap({ "n", "v" }, "<Tab>", ":Telescope buffers theme=ivy<CR>", { desc = "Live grep", silent = true })

keymap(
	"n",
	"<leader>fi",
	"<cmd>:lua require'telescope.builtin'.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({}))<CR>",
	{ desc = "Live grep in Current file", silent = true }
)

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
keymap(
	"n",
	"<leader>cf",
	"<cmd>:lua require'telescope.builtin'.treesitter(require('telescope.themes').get_ivy({}))<CR>",
	{ desc = "Find Functions,Variables and more", silent = true }
)
keymap("n", "<leader>ca", "<cmd>:Lspsaga code_action<CR>", { desc = "Code Actions", silent = true })
keymap(
	"n",
	"<leader>ce",
	"<cmd>:lua require('telescope.builtin').diagnostics(require('telescope.themes').get_ivy({}))<CR>",
	{ desc = "Code Diagnostics", silent = true }
)
keymap(
	"n",
	"<leader>cq",
	"<cmd>:lua require'telescope.builtin'.quickfix(require('telescope.themes').get_ivy({})) <CR>",
	{ desc = "Quick Fix List", silent = true }
)
keymap(
	"n",
	"<leader>cs",
	"<cmd>:lua vim.diagnostic.open_float()<CR>",
	{ desc = "Show whole Code warning/error/suggestion", silent = true }
)
keymap(
	"n",
	"<leader>ci",
	"<cmd>:lua require('telescope.builtin').lsp_implementations(require('telescope.themes').get_cursor({}))<CR>",
	{ desc = "Code Definitions", silent = true }
)

-- Git
keymap(
	"n",
	"<leader>glb",
	"<cmd>:Gitsigns toggle_current_line_blame<CR>",
	{ desc = "Toggle Line blames", silent = true }
)
keymap("n", "<leader>gg", "<cmd>:LazyGit<CR>", { desc = "Toggle LazyGit UI", silent = true })
keymap("n", "<leader>gb", "<cmd>:Git blame<CR>", { desc = "Open Git Blames", silent = true })

-- Containers
local container_engine = vim.fn.executable("podman") == 1 and "podman" or "docker"
keymap(
	"n",
	"<F3>",
	"<cmd>:lua LazyDocker.toggle({engine = '" .. container_engine .. "'})<CR>",
	{ desc = "Toggle LazyDocker (" .. container_engine .. ")", silent = true }
)

-- Pi agent
keymap({ "n", "v" }, "<leader>pp", ":Pi<CR>")
keymap({ "n", "v" }, "<leader>ps", ":PiSessions<CR>")

keymap(
	{ "n", "t", "v" },
	"<F1>",
	require("plugins.sidebars").toggle_dadbod,
	{ desc = "Toggle DadBod UI", silent = true }
)

keymap(
	{ "n", "t", "v" },
	"<leader>tv",
	require("plugins.terminal").toggle_right_terminal,
	{ desc = "Toggle Right Terminal", silent = true }
)

keymap(
	{ "n", "t" },
	"<leader>th",
	require("plugins.horizontal_terminal").toggle_bottom_terminal,
	{ desc = "Toggle Bottom Terminal", silent = true }
)

keymap({ "n", "v" }, "<C-s>", ":w<CR>", { desc = "Save File", silent = true })

keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })

keymap({ "n", "v" }, "<C-w>s", "<Cmd>Persisted save<CR>", { desc = "Save session" })

keymap({ "v", "n", "t" }, "<C-w>%", "<Cmd>rightbelow vsplit | term<CR>", { desc = "Open terminal in vertical split" })

keymap({ "v", "n", "t" }, '<C-w>"', "<Cmd>rightbelow split | term<CR>", { desc = "Open terminal in horizontal split" })

keymap({ "v", "n", "t" }, "<C-w><Left>", "<Cmd>vertical resize -5<CR>", { desc = "Shrink window width" })

keymap({ "v", "n", "t" }, "<C-w><Right>", "<Cmd>vertical resize +5<CR>", { desc = "Grow window width" })

keymap({ "v", "n", "t" }, "<C-w><Up>", "<Cmd>horizontal resize +5<CR>", { desc = "Grow window height" })

keymap({ "v", "n", "t" }, "<C-w><Down>", "<Cmd>horizontal resize -5<CR>", { desc = "Shrink window height" })
