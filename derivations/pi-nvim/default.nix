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
# Version skew to keep in mind: the two halves of the bridge come from
# different pins on purpose. Neovim loads this build (rev ecd6b71, v0.2.6);
# `pi` loads the plugins/pi-nvim submodule checkout (gitlink 2451d2f), which
# is a backward-compatible superset: it forwards prompt options and images,
# hardens the socket bridge against stale clients, and accepts arguments on
# `:Pi`/`:PiSend`. The wire protocol is unchanged, so either side works alone.
# This replaced the published `npm:pi-nvim@0.2.5`, which dropped the
# per-message options and so never honoured `expandPromptTemplates`.
#
# If a future nvim-side feature depends on a newer bridge, bump the `rev`
# here and the gitlink in the superproject in the same change.
vimUtils.buildVimPlugin {
  pname = "pi-nvim";
  version = "v0.2.7";
  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "pi-nvim";
    rev = "main";
    # sha256 = lib.fakeHash;
    sha256 = "sha256-7KY+TVbeF5tPgs+cdpOmvGPbx+eq0V9baj02Jr3Ja8I=";
  };
  meta.description = "Bridge between pi coding agent and Neovim";
}
