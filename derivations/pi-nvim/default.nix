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
# Version skew to keep in mind: this is the Neovim side of the bridge
# (package.json 0.2.6 here), while `pi` loads its own copy from npm
# (`npm:pi-nvim`). The two halves talk over a newline-delimited JSON socket,
# and the peer range in package.json (`^0.87.0`) is wider than the `pi`
# 0.86.1 this flake ships; the protocol used here is unchanged since 0.2.5.
vimUtils.buildVimPlugin {
  pname = "pi-nvim";
  version = "v0.2.6";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "pi-nvim";
    rev = "25ea744c702412f46d5eaa71c1c7e9bb131940ee";
    sha256 = "sha256-4d0fnkjyCTvFurZxg+ZAElQogNALheHuia6v0Db3nQ4=";
  };
  meta.description = "Bridge between pi coding agent and Neovim";
}
