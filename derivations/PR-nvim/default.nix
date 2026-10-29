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
    # 9fa2ab9 = ":PR complete" plus a finished PR's commits, files and
    # approvals, on branch feat/pr-complete; move to "main" once that merge
    # request is in.
    rev = "9fa2ab987bd71d0bb23708604f91b266e51c3490";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-/f7XuBPkDBF2dn6muuU3DdS4MdE/3AjIOr0ps91bCP4=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
