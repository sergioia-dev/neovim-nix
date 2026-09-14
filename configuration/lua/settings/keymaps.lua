vim.g.mapleader = " "
vim.g.maplocalleader = " "

local keymap = vim.keymap.set

keymap("n", "<leader>ft", ":ProjectTree<CR>", { desc = "Toggle Project Tree", silent = true })

-- Navigation
keymap("n", "<leader>fm", require("plugins.sidebars").lexplore, { desc = "Open Explorer / DBUI", silent = true })

keymap("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files", silent = true })

keymap("n", "<leader>tt", ":TodoTelescope<CR>", { desc = "Find Todo comments", silent = true })

keymap("n", "<leader>fa", ":Telescope live_grep theme=dropdown<CR>", { desc = "Live grep", silent = true })
keymap(
	"n",
	"<leader>fi",
	"<cmd>:lua require'telescope.builtin'.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({}))<CR>",
	{ desc = "Live grep in Current file", silent = true }
)
keymap("n", "<leader>fh", ":Telescope help_tags<CR>", { desc = "Fuzzy search Documentation", silent = true })

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
	"<F2>",
	"<cmd>:lua LazyDocker.toggle({engine = '" .. container_engine .. "'})<CR>",
	{ desc = "Toggle LazyDocker (" .. container_engine .. ")", silent = true }
)

-- Pi agent
keymap({ "n", "v" }, "<leader>pp", ":Pi<CR>")
keymap("v", "<leader>ps", ":PiSendSelection<CR>")
keymap({ "n", "v" }, "<leader>ps", ":PiSessions<CR>")

-- Database
-- keymap(
-- 	{ "n", "v" },
-- 	"<F1>",
-- 	require("plugins.sidebars").toggle_datagrip,
-- 	{ desc = "Toggle Data Grip Sidebar", silent = true }
-- )

keymap({ "n", "v" }, "<F1>", require("plugins.sidebars").toggle_dadbod, { desc = "Toggle DadBod UI", silent = true })

keymap({ "n", "v" }, "<C-s>", ":w<CR>", { desc = "Save File", silent = true })
