{
  lib,
  vimUtils,
}:

# nvim-pr lives in this repository (./plugins/nvim-pr) as a plain tracked
# directory, not a submodule, so the source can be copied straight out of the
# flake instead of being fetched from a remote.
#
# cleanSource keeps build products (result symlinks, .git) out of the store copy.
vimUtils.buildVimPlugin {
  pname = "nvim-pr";
  version = "0.1.0";
  src = lib.cleanSource ../../plugins/nvim-pr;
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
