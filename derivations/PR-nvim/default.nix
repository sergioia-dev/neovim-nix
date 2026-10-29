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
    # a735343 = ":PR complete" on branch feat/pr-complete; move to "main" once
    # that merge request is in.
    rev = "a735343b980a81abb28e6979d65b870f269d5396";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-xqSiReeaoPVhxf1x8ereTG5Ac0K0JGG7rnHOK6oCQpc=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
