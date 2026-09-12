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
        vimPlugins = prev.vimPlugins // {
          pi-nvim = final.callPackage ./derivations/pi-nvim { };
          dadbod-grip-nvim = final.callPackage ./derivations/dadbod-grip-nvim { };
          project-tree-nvim = final.callPackage ./derivations/project-tree-nvim { };
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
            pyright
            rust-analyzer
          ];

          LSPs-minimal = with pkgs; [
            docker-language-server
            bash-language-server
            nixd
          ];

          formatters = with pkgs; [
            stylua
            sql-formatter
            biome
            nixfmt
            black
            shfmt
            kulala-fmt
            rustfmt
          ];

          formatters-minimal = with pkgs; [
            sql-formatter
            nixfmt
            shfmt
          ];

          pluginDependencies = with pkgs; [
            ripgrep
            git
            lldb
            lazygit
            lazydocker
            jq
            lsof
            luaPackages.tree-sitter-cli
            luaPackages.jsregexp
            cargo
            tree
          ];

          pluginDependencies-minimal = with pkgs; [
            curl
            ripgrep
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

          minimal = pkgs.callPackage ./minimal/neovim-minimal.nix {
            configuration = pkgs.runCommandLocal "configuration" { } ''
              mkdir -p $out
              cp -r ${./minimal/configuration}/* $out
            '';
            runtimeDependencies = LSPs-minimal ++ formatters-minimal ++ pluginDependencies-minimal;
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
            buildInputs = [
              pkgs.luajit
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
