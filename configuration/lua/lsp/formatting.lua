require("conform").setup({
	formatters_by_ft = {

		lua = { "stylua", lsp_format = "fallback" },
		python = { "black", lsp_format = "fallback" },
		rust = { "rustfmt", lsp_format = "fallback" },
		javascript = { "biome", lsp_format = "fallback" },
		javascriptreact = { "biome", lsp_format = "fallback" },
		typescriptreact = { "biome", lsp_format = "fallback" },
		typescript = { "biome", lsp_format = "fallback" },
		json = { "biome", lsp_format = "fallback" },
		jsonc = { "biome", lsp_format = "fallback" },
		css = { "biome", lsp_format = "fallback" },
		graphql = { "biome", lsp_format = "fallback" },
		nix = { "nixfmt", lsp_format = "fallback" },
		bash = { "shfmt", lsp_format = "fallback" },
		sql = { "sql_formatter", lsp_format = "fallback" },
		http = { "kulala-fmt", lsp_format = "fallback" },
		rest = { "kulala-fmt", lsp_format = "fallback" },
	},
	format_on_save = true,
})
