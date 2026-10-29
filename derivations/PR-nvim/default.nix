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
    # f174c9a = ":PR complete" plus a finished PR's commits, files and
    # approvals, on branch feat/pr-complete; move to "main" once that merge
    # request is in.
    rev = "f174c9a612ce61cd94e6e637d86e4d317ed3bf51";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-Y3r7sNNDFSWa2ZLrzKb81SCkGphPlzYxpGmWCddHzJQ=";
  };
  meta.description = "Create, list, view, check out and merge pull requests from Neovim";
  doCheck = false;
}
