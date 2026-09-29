{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

# net_picker.nvim is developed in https://github.com/sergioia-dev/net_picker and
# vendored here as the ./plugins/net_picker submodule.
#
# A submodule's working tree is not part of a flake's source, so the plugin must
# be fetched from its own repository (like project-tree-nvim).
#
# `rev` is pinned to the commit that added lua/net_picker/. Once that commit is
# on `main` this can become rev = "main" — the tree is identical, so the sha256
# below keeps matching.
vimUtils.buildVimPlugin {
  pname = "net-picker.nvim";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "net_picker";
    rev = "b5f44c0cb472bc6263cb567408cbaedf76a6f8dd";
    sha256 = "sha256-c8muz2oYfqYl4IHCcnAAJZPMPJXBwvAnRs1ktopZ/Ww=";
  };
  meta.description = "Network process + container picker for Neovim, backed by Telescope or fzf-lua";
  doCheck = false;
}
