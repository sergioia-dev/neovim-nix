{
  vimUtils,
  fetchFromGitHub,
}:

# code-helper.nvim is developed in https://github.com/sergioia-dev/code-helper-nvim
# and published there, so it is fetched like net_picker/project-tree-nvim rather
# than built from a directory in this repo.
#
# `rev` is pinned to the commit that introduced plugin/ + lua/code_helper/.
# Bump it and re-run `nix build --no-link .#` to pick up new commits.
vimUtils.buildVimPlugin {
  pname = "code-helper-nvim";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "code-helper-nvim";
    rev = "8667430a267e203c2b4b0e3905135a80fc39e1f6";
    sha256 = "sha256-QiAFEohTDBWH78pnf6NxMRDGQ1NPA7BMK18JCZ9Ddhw=";
  };
  meta.description = "Base64/URL conversion commands and a URL-safe JWT secret generator for Neovim";
  doCheck = false;
}
