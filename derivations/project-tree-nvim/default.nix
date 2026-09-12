{ vimUtils }:
vimUtils.buildVimPlugin {
  pname = "project-tree-nvim";
  version = "0.1.0";
  src = ./../../plugin/project-tree-nvim;
  meta.description = "Render project tree in a floating window using tree CLI";
}
