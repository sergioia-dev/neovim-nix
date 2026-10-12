{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
}:

# dbtui is developed and published in https://github.com/Di3go0-0/dbtui, so it
# is fetched from upstream like the plugins in this directory are.
#
# This is the same derivation that is prepared for Nixpkgs
# (pkgs/by-name/db/dbtui/package.nix), kept here so the flake can build it
# without waiting for that pull request to be merged. The only difference is
# meta.maintainers: `lib.maintainers.sergioia-dev` does not exist in every
# Nixpkgs revision, so the entry is written out inline.
#
# Bump `version` and the two hashes together:
#   nix build --no-link .#dbtui        # reports the new src hash on mismatch
#   nix-prefetch-url --unpack ...      # or replace both hashes with lib.fakeHash
#
# Upstream gitignores its Cargo.lock, so a lock file generated from the tagged
# Cargo.toml is kept in this directory and copied into the source tree before
# vendoring (see cargoLock/postPatch below).
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "dbtui";
  version = "0.5.0";

  # Kept so this stays byte-identical to the Nixpkgs submission.
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "Di3go0-0";
    repo = "dbtui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4xIPwR5snakdVVZO9Nc54/Sy4liIYTT2ofUzKlh1lmM=";
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    # native-tls, pulled in by sqlx
    openssl
  ];

  meta = {
    description = "Terminal database client with Vim-style navigation";
    longDescription = ''
      A TUI database client with Vim-style navigation, supporting PostgreSQL,
      MySQL, SQL Server and Oracle. It offers a query editor, an explorer for
      the schema, editable result grids, multiple tabs and connections, and
      encrypted storage of saved connections.
    '';
    homepage = "https://github.com/Di3go0-0/dbtui";
    changelog = "https://github.com/Di3go0-0/dbtui/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = [
      {
        name = "Sergio IA";
        github = "sergioia-dev";
        githubId = 175462788;
      }
    ];
    mainProgram = "dbtui";
    platforms = lib.platforms.unix;
  };
})
