# Nix-Wrapped Neovim Configuration

A custom Neovim configuration wrapped with Nix for easy installation and management.

## Features

### Coding

| Languages Available     | Formatter |
| ----------------------- | --------- |
| TypeScript / JavaScript | ✔️        |
| Python                  | ✔️        |
| Rust                    | ✔️        |
| Java                    | ✔️        |
| Lua                     | ✔️        |
| Nix                     | ✔️        |
| Dart / Flutter          | ✔️        |
| Bash                    | ✔️        |
| JSON                    | ✔️        |
| YAML                    | ✔️        |
| CSS                     | ✔️        |
| Markdown                | ✔️        |
| SQL                     | ✔️        |

### Git

- Stage, commit, branch, and view history without leaving Neovim
- Inline diff markers showing added/changed/deleted lines
- View who last modified each line (blame)

### Docker

- Manage containers directly from Neovim
- View and manage images, volumes, and networks
- Works with both Docker and Podman

### Databases

- Connect to PostgreSQL, MongoDB, MySQL, SQLite, Redis, Big Query, ClickHouse, DuckDB, Impala, jq, MariaDB, Oracle, osquery, Presto, Snowflake and SQL Server
- Execute queries and browse results
- Save connections for quick access

### REST APIs

- Test HTTP endpoints directly in Neovim
- Create requests in `.http` or `.rest` files

### Markdown

- Write and preview Markdown directly in Neovim
- Live preview with `:MarkdownPreview` command

## Quick Commands

| Command            | Action            |
| ------------------ | ----------------- |
| `:LazyGit`         | Git TUI           |
| `:LazyDocker`      | Docker/Podman TUI |
| `:DBManagerToggle` | Database browser  |
| `:FlutterRun`      | Run Flutter app   |
| `:NvimTreeToggle`  | File explorer     |
| `:MarkdownPreview` | Preview Markdown  |

## Prerequisites

- [Nix](https://nixos.org/download.html) installed on your system
- Flakes enabled (add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`)

# Installation

## Via Nix Profile (Recommended)

Install directly from GitHub:

```bash
nix profile add github:sergioia-dev/Nix-Neovim
```

Or install locally after cloning:

```bash
nix profile add .
```

## As a Flake App

Test without installing:

```bash
nix run github:sergioia-dev/Nix-Neovim
```

Build the package:

```bash
nix build github:sergioia-dev/Nix-Neovim
```

## Home Manager Integration

This flake does not currently ship a Home Manager module. You can add the package directly:

```nix
{ inputs, ... }: {
  home.packages = [ inputs.neovim.packages.${pkgs.system}.default ];
}
```

## NixOS Integration

This flake does not currently ship a NixOS module. You can add the package to `environment.systemPackages`:

```nix
{ inputs, ... }: {
  environment.systemPackages = [ inputs.neovim.packages.${pkgs.system}.default ];
}
```

# Usage

Run Neovim:

```bash
nvim
```

## Documentation

| Question                         | Answer                               |
| -------------------------------- | ------------------------------------ |
| What languages are supported?    | [docs/coding.md](docs/coding.md)     |
| What plugins are installed?      | [docs/plugins.md](docs/plugins.md)   |
| What are the keyboard shortcuts? | [docs/keymaps.md](docs/keymaps.md)   |
| How to connect to a database?    | [docs/database.md](docs/database.md) |
| How to test REST APIs?           | [docs/rest.md](docs/rest.md)         |
