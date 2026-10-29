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
    # 37fc218 = ":PR complete" on branch feat/pr-complete; move to "main" once
    # that merge request is in.
    rev = "37fc21811766553234ac838ac21367c303a00d80";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-NdFWfx9R0kAYrWp45yY9VG3M5Rr5WPfAXCS4FShe650=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
