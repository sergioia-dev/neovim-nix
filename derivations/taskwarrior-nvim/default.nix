{
  fetchFromGitHub,
  lib,
  vimUtils,
}:

# taskwarrior-nvim lives in this repository under `plugins/taskwarrior`, so it is
# built straight from that directory instead of being fetched from GitHub like
# code-helper-nvim and toggable-term-nvim. `lib.cleanSource` keeps the flake
# source honest: only tracked files under `plugins/taskwarrior` become the
# derivation source. Moving the plugin to its own repository later means
# swapping `lib.cleanSource` for `fetchFromGitHub` and dropping the directory.
vimUtils.buildVimPlugin {
  pname = "taskwarrior-nvim";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "taskwarrior-nvim";
    rev = "main";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-7lJHtZ9LlDzDVpIHtnuQVZdWBYH2mwJywl7hBjIvbOg=";
  };

  meta.description = "Taskwarrior reports in a bottom split, commands headless";
  doCheck = false;
}
