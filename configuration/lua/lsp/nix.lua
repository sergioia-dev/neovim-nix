vim.lsp.config("nixd", {
	cmd = { "nixd" },
	filetypes = { "nix" },
	root_markers = { "flake.nix", ".git" },
	settings = {
		nixd = {
			formatting = {
				command = { "nixfmt" },
			},
			options = {
				nixos = {
					expr = [[(builtins.getFlake "/home/sia/Nix-Ecosystem").nixosConfigurations.desktop-personal.options]],
				},
				["home-manager"] = {
					expr = [[(builtins.getFlake "/home/sia/Nix-Ecosystem").homeConfigurations.personal.options]],
				},
			},
		},
	},
})

if vim.fn.executable("nixd") == 1 then
	vim.lsp.enable("nixd")
end
