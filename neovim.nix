{
  lib,
  symlinkJoin,
  neovim-unwrapped,
  makeWrapper,
  runCommandLocal,
  vimPlugins,
  configuration,
  runtimeDependencies,
  pkgs,
  pkgs-unstable,
}:
let

  packageName = "custom";

  startPlugins = [
    vimPlugins.rustaceanvim
    vimPlugins.lualine-nvim
    vimPlugins.nvim-autopairs
    vimPlugins.luasnip
    vimPlugins.friendly-snippets
    vimPlugins.which-key-nvim
    vimPlugins.telescope-nvim
    vimPlugins.plenary-nvim
    vimPlugins.gitsigns-nvim
    vimPlugins.render-markdown-nvim
    vimPlugins.nvim-lspconfig
    vimPlugins.nvim-cmp
    vimPlugins.cmp-nvim-lsp
    vimPlugins.cmp_luasnip
    vimPlugins.cmp-path
    vimPlugins.cmp-buffer
    vimPlugins.lspkind-nvim
    vimPlugins.lspsaga-nvim
    vimPlugins.nvim-jdtls
    vimPlugins.catppuccin-nvim
    vimPlugins.conform-nvim
    vimPlugins.nvim-lint
    vimPlugins.vim-dadbod-ui
    vimPlugins.vim-dadbod-completion
    vimPlugins.vim-dadbod
    vimPlugins.dressing-nvim
    vimPlugins.todo-comments-nvim
    vimPlugins.nvim-treesitter.withAllGrammars
    vimPlugins.nui-nvim
    vimPlugins.nvim-notify
    vimPlugins.noice-nvim
    vimPlugins.smear-cursor-nvim
    vimPlugins.lazygit-nvim
    vimPlugins.kulala-nvim
    vimPlugins.flutter-tools-nvim
    vimPlugins.nix-develop-nvim
    vimPlugins.pi-nvim
    vimPlugins.project-tree-nvim
    configuration
  ];

  foldPlugins = builtins.foldl' (
    acc: next:
    acc
    ++ [
      next
    ]
    ++ (foldPlugins (next.dependencies or [ ]))
  ) [ ];

  startPluginsWithDeps = lib.unique (foldPlugins startPlugins);

  packpath = runCommandLocal "packpath" { } ''
    mkdir -p $out/pack/${packageName}/{start,opt}

    ${lib.concatMapStringsSep "\n" (
      plugin: "ln -vsfT ${plugin} $out/pack/${packageName}/start/${lib.getName plugin}"
    ) startPluginsWithDeps}
  '';
in
symlinkJoin {
  name = "neovim-custom";
  paths = [ neovim-unwrapped ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/nvim \
      --add-flags '-u NORC' \
      --add-flags '--cmd' \
      --add-flags "'set packpath^=${packpath} | set runtimepath^=${packpath}'" \
      --set-default NVIM_APPNAME nvim-custom \
      --prefix PATH : ${lib.makeBinPath runtimeDependencies}
  '';
}
