{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  sqlite,
  postgresql,
  mariadb,
}:

# sql-mer-tui (binary: sqlv) is developed and published in
# https://github.com/sergioia-dev/sql-mer-tui and is used as an optional
# companion to the vim-dadbod-manager drawer: its "Schema viewer" entry opens
# the ER diagram TUI on the current connection.
#
# Upstream builds with Crane, but the sources are an ordinary Cargo package
# with a committed Cargo.lock, so the plain `rustPlatform.buildRustPackage`
# path is enough here.
#
# Bump `version` and both hashes together, after a `nix build --no-link` run:
#   nix build --no-link .#sql-mer-tui   # reports the real src/cargo hashes
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sql-mer-tui";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "sergioia-dev";
    repo = "sql-mer-tui";
    # Pinned to the commit that makes SQL Server `?query` options (encrypt,
    # trustServerCertificate) reach tiberius; it stays reachable from `main`
    # once the fix/mssql-url-query-params branch is merged.
    rev = "main";
    hash = "sha256-dHbv6e9kmYBpv5wK8o7ZT2w4dit4qzvPEjwa3x43PRk=";
  };

  # Cargo.lock is committed upstream, so the classic cargoHash path uses it
  # directly; no lock file has to be vendored into this directory.
  cargoHash = "sha256-F7pBevGVYmZ5hpfdtpJKSbn/c9qr/J+D5tGZwKNHZE0=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    openssl # TLS for the Postgres/MySQL drivers and for tiberius
    sqlite # libsqlite3 for the sqlx SQLite driver
    postgresql # libpq + headers for the postgres -sys crate
    mariadb # libmariadb + headers for the sqlx MySQL driver
  ];

  # The sqlx `-sys` crates must link the Nix libraries, not their vendored
  # copies, so make pkg-config prefer the ones from buildInputs above.
  env = {
    OPENSSL_NO_VENDOR = 1;
  };

  meta = {
    description = "Render a SQL database schema as an interactive terminal diagram";
    longDescription = ''
      A keyboard-driven terminal ER diagram viewer. It connects to a live SQL
      database, introspects its tables, columns, primary keys and foreign keys,
      and draws the result as a pannable, zoomable diagram of boxes and
      connector lines. Supports PostgreSQL, MySQL, MariaDB, SQL Server and
      SQLite.
    '';
    homepage = "https://github.com/sergioia-dev/sql-mer-tui";
    license = lib.licenses.mit;
    mainProgram = "sqlv";
    platforms = lib.platforms.unix;
  };
})
