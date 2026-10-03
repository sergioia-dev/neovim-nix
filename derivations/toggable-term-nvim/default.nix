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
    rev = "85844bc54daf3e1e8c8fc42ef11cef4a7e77056a";
    sha256 = "sha256-a0xEw5xf1jXQcprVJOj0BpcldPEtj6e/jYLSkrG9UtU=";
  };
  meta.description = "Focus-aware vertical, horizontal and floating terminal sidebars for Neovim";
  doCheck = false;
}
