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
    # 2a52356 = ":PR complete" plus a finished PR's commits, files and
    # approvals, read from every provider (github, gitlab, azure), on branch
    # feat/pr-complete; move to "main" once that merge request is in.
    rev = "2a523563ab7d0a6b77cd1e578ee9a67fb9bdb97a";
    sha256 = "sha256-cN4d58EX+Nj/n/T5HQneU7qRv0i9x0mnc+Ha/YBGyss=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
