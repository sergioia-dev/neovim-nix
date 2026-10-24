{
  description = "My Neovim configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
    }:
    let
      lib = nixpkgs.lib;

      pluginDerivationsOverlay = final: prev: {

        # Optional companion for the vim-dadbod-manager drawer: the
        # `sqlv` ER-diagram TUI, opened from the "Schema viewer" entry.
        sqlv = final.callPackage ./derivations/sql-mer-tui { };

        vimPlugins = prev.vimPlugins // {
          pi-nvim = final.callPackage ./derivations/pi-nvim { };
          net_picker = final.callPackage ./derivations/net_picker { };
          code-helper-nvim = final.callPackage ./derivations/code-helper-nvim { };
          toggable-term-nvim = final.callPackage ./derivations/toggable-term-nvim { };
          taskwarrior-nvim = final.callPackage ./derivations/taskwarrior-nvim { };
          vim-dadbod-manager = final.callPackage ./derivations/vim-dadbod-manager { };
          nvim-pr = final.callPackage ./derivations/nvim-pr { };
        };
      };

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend pluginDerivationsOverlay;
          pkgs-unstable = nixpkgs-unstable.legacyPackages.${system}.extend pluginDerivationsOverlay;
        in
        let
          LSPs = with pkgs; [
            typescript-go
            lua-language-server
            vscode-langservers-extracted
            docker-language-server
            jdt-language-server
            bash-language-server
            nixd
          ];

          formatters = with pkgs; [
            stylua
            sql-formatter
            biome
            nixfmt
            shfmt
            kulala-fmt
          ];

          pluginDependencies = with pkgs; [
            ripgrep
            git
            lldb
            jq
            lsof
            luaPackages.tree-sitter-cli
            luaPackages.jsregexp
            fzf
            sqlv # sqlv, the "Schema viewer" backend in the vim-dadbod-manager drawer
            taskwarrior3
          ];

        in
        {
          default = pkgs.callPackage ./neovim.nix {
            configuration = pkgs.runCommandLocal "configuration" { } ''
              mkdir -p $out
              cp -r ${./configuration}/* $out
            '';
            runtimeDependencies = LSPs ++ formatters ++ pluginDependencies;
            inherit pkgs-unstable;
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/nvim";
        };

        minimal = {
          type = "app";
          program = "${self.packages.${system}.minimal}/bin/nvim";
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            # The CLI login is the only thing nvim-pr needs; keeping the three
            # providers' CLIs here lets `:PR create` be tried from `nix develop`
            # without the nvim wrapper bundling them.
            buildInputs = [
              pkgs.luajit
              pkgs.gh
              pkgs.glab
              (pkgs.azure-cli.withExtensions [ pkgs.azure-cli.extensions.azure-devops ])
            ];
          };
        }
      );

      meta = {
        description = ''
          === My custom Neovim configuration ===
          Build:
            - nix run .
            - nix build .
            - nix develop
        '';
      };
    };
}
