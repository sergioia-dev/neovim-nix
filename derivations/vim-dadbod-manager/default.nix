{
  vimUtils,
  fetchFromGitHub,
}:

# vim-dadbod-manager is developed and published in
# https://github.com/sergioia-dev/vim-dadbod-manager, so it is fetched like
# code-helper-nvim, net_picker, project-tree-nvim and toggable-term-nvim rather
# than built from a directory in this repo. It also lives in ./plugins as a
# submodule, which is a working copy only: a flake never sees a submodule's tree.
#
# `rev = "main"` follows the branch and the sha256 below pins the tree that must
# match it. When upstream pushes, `nix build` fails with the new hash to paste
# here (re-check with `nix build --no-link --refresh .`).
vimUtils.buildVimPlugin {
  pname = "vim-dadbod-manager";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "vim-dadbod-manager";
    rev = "main";
    sha256 = "sha256-mL98bfxm5J52d0xD0YzWW7qVmdHb3sXG3la4wikKEe0=";
  };
  meta.description = "Server -> databases -> tables tree for vim-dadbod-ui connections";
  doCheck = false;
}
