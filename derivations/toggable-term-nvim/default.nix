{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

# toggable-term-nvim is developed and published in
# https://github.com/sergioia-dev/toggable-term-nvim, so it is fetched like
# code-helper-nvim, net_picker and project-tree-nvim rather than built from a
# directory in this repo.
#
# `rev` is pinned to the last version of the plugin that also lived in this repo:
# the one with the three terminal kinds (vertical, horizontal, floating) and the
# size options. Bump it and re-run `nix build --no-link .` to pick up new commits.
vimUtils.buildVimPlugin {
  pname = "toggable-term-nvim";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "toggable-term-nvim";
    rev = "713633355ced060f5337e6ce5271db67367bbf16";
    sha256 = "sha256-Bs3elJzzzi1WiqwP0TnXEkUdwjizO2OckaNBTX6iGRM=";
  };
  meta.description = "Focus-aware vertical, horizontal and floating terminal sidebars for Neovim";
  doCheck = false;
}
