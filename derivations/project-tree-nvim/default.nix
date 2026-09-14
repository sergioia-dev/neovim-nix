{
  lib,
  vimUtils,
  fetchFromGitHub,
}:
vimUtils.buildVimPlugin {
  pname = "project-tree-nvim";
  version = "0.1.0";
  src = fetchFromGitHub {

    owner = "sergioia-dev";
    repo = "project-tree.nvim";
    rev = "main";
    sha256 = "sha256-X3fHoLmf5Qd2HGdzcJT3qllOFmnQLMf+7SenK+cv56g=";
  };
  meta.description = "Render project tree in a floating window using tree CLI";
}
