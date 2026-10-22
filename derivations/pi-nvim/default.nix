{
  lib,
  vimUtils,
  fetchFromGitHub,
}:

# The fork has no tags, so the source is pinned to a commit: `rev = "main"`
# would silently rebuild on every upstream push. Bump `rev`, `version` and
# `sha256` together, e.g.
#   nix-prefetch-url --unpack --type sha256 \
#     "https://github.com/sergioia-dev/pi-nvim/archive/<rev>.tar.gz"
#   nix hash convert --to sri --hash-algo sha256 <base32 hash>
#
# Version skew to keep in mind: `pi` loads this same checkout as a local
# extension (see pi-nix: `extraExtensions = [ ".../neovim-nix/plugins/pi-nvim" ]`),
# so the two halves of the bridge are the same commit. That replaced the
# published `npm:pi-nvim@0.2.5`, which dropped the per-message options and so
# never honoured `expandPromptTemplates`.
vimUtils.buildVimPlugin {
  pname = "pi-nvim";
  version = "v0.2.6";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "pi-nvim";
    rev = "ecd6b71c9a70331e58f25da9be871fb75ed35bde";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-9TB3/ZDls16jB/ay9QW6EjjyqLnc3JEhHhEtMMi7hpo=";
  };
  meta.description = "Bridge between pi coding agent and Neovim";
}
