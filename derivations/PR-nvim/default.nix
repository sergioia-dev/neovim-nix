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
    # f5d0f78 = ":PR complete" with each commit's files on Tab and the
    # identity row ordered id, author, state, verdict, read from every provider
    # (github, gitlab, azure), on branch feat/pr-complete; move to "main" once
    # that merge request is in.
    rev = "main";
    sha256 = "sha256-EnZqQNbbjdlJ0bVkWpzCjMnfOHYLnzbLZC5BHmbZOqI=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
