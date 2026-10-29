{
  lib,
  fetchFromGitLab,
  vimUtils,
}:

# nvim-pr lives in its own GitLab repository (sergioia-dev/pr-nvim); a working
# checkout sits in ./plugins/PR-nvim for editing, but the build fetches the
# pinned commit, so a change only lands here after it is pushed and `rev` and
# `sha256` below are refreshed.
vimUtils.buildVimPlugin {
  pname = "nvim-pr";
  version = "0.1.0";
  src = fetchFromGitLab {
    owner = "sergioia-dev";
    repo = "PR-nvim";
    # be13d17 = ":PR complete" plus a finished PR's commits, files and
    # approvals, read from every provider (github, gitlab, azure), on branch
    # feat/pr-complete; move to "main" once that merge request is in.
    rev = "f2ffefaf405c7af8a6ea3139ed3990be44bd8075";
    sha256 = "sha256-m8yJPWG+1wP0pl5mcFk8qpPzq40bBUOdeHc6WIwkIcE=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
