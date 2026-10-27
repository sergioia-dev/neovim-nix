# Nix-Wrapped Neovim Configuration

A personal Neovim configuration wrapped with Nix and pinned to `nixos-26.05`.
Language servers, formatters and CLI tools are packaged by the flake, the Lua
configuration uses the built-in `vim.lsp.config` / `vim.lsp.enable` API, and the
whole setup is wired together as a single `neovim-custom` derivation.

## Features

### Coding

| Language | Language server | Enabled when |
| --- | --- | --- |
| TypeScript / JavaScript | `tsgo` | `node`, `bun` or `deno` is on `PATH` |
| Lua | `lua-language-server` | `lua` or `luajit` is on `PATH` |
| Nix | `nixd` | `nixd` is on `PATH` |
| Java | `jdtls` | `JAVA_HOME` is set (`LOMBOK_JAR` adds the javaagent) |
| Dart / Flutter | `flutter-tools` defaults | always |
| Bash / Shell | `bash-language-server` | always |
| HTML / CSS / JSON | `html`, `cssls`, `jsonls` | always |

Python and Rust have no language server configured.

The Nix LSP options point at the author's own flake, so
`configuration/lua/lsp/nix.lua` has to be adjusted for another system.

### Formatting

Formatting runs on save through `conform.nvim`:

| Language | Formatter |
| --- | --- |
| Lua | `stylua` |
| JavaScript / TypeScript / JSX / TSX | `biome` |
| HTML | `biome` |
| JSON / JSONC | `biome` |
| CSS | `biome` |
| GraphQL | `biome` |
| Nix | `nixfmt` |
| Bash / Shell | `shfmt` |
| SQL | `sql-formatter` |
| HTTP / REST | `kulala-fmt` |

Python, Rust, Java, Dart/Flutter and Markdown are not formatted.

### Linting

`nvim-lint` runs `biome` on JavaScript, TypeScript, JSX and TSX, and the `nix`
linter from `vscode-langservers-extracted` on Nix files.

### Completion

`nvim-cmp` completes from `nvim_lsp`, `luasnip`, `path`, `buffer` and
`vim-dadbod-completion`, with `lspkind` icons and bordered documentation
windows. Snippets come from `LuaSnip` plus `friendly-snippets` (VSCode snippet
packs), with `html` snippets extended into `typescriptreact` and
`javascriptreact`.

| Key | Action |
| --- | --- |
| `<C-Space>` | Trigger completion |
| `<C-n>` / `<C-p>` | Next / previous item |
| `<C-f>` / `<C-b>` | Scroll documentation |
| `<CR>` | Confirm |
| `<Esc>` | Abort |

### Git

- Neogit for staging, committing, branching and history (`:Neogit kind=replace`)
- gitsigns for inline diff signs, staged signs and toggleable line blame
- fzf-lua pickers for branches and commits
- nvim-pr for pull requests on GitHub, GitLab and Azure DevOps (`:PR`, see [Pull requests](#pull-requests-nvim-pr))
### Databases

- vim-dadbod with vim-dadbod-manager's server → databases → tables tree
- Supports BigQuery, ClickHouse, DuckDB, Impala, MongoDB, MySQL, MariaDB,
  Oracle, osquery, PostgreSQL, Presto, Redis, Snowflake, SQL Server and SQLite
- Connections and their credentials are stored in
  `~/.cache/nvim-custom/vim-dadbod-manager/connections.json`
- If none of those clients is on `PATH` the sidebar reports a warning instead of
  opening

### REST APIs

- Test HTTP endpoints inside Neovim with `kulala-nvim`
- Requests live in `.http` or `.rest` files and open in a float, with the
  plugin's global keymaps enabled
- Requests are formatted on save with `kulala-fmt`

### Markdown

`render-markdown.nvim` renders Markdown inside the buffer (LaTeX is disabled).

### Terminals

`toggable-term-nvim` provides right and bottom terminals that close when they
lose focus. The terminal buffer is cached, so the shell session and scrollback
survive and the next toggle restores the same terminal. Only one sidebar —
terminal, database tree or file explorer — is visible at a time.

### AI agent

`pi-nvim` bridges the `pi` coding agent into Neovim. `<leader>a` toggles a
vertical terminal that starts `pi` lazily on the first toggle, and `<leader>p`
opens the `:Pi` dialog that sends a prompt (or the visual selection) to it.

`:Pi <text>` skips the dialog and sends the text as typed, so slash commands work
from the command line: `:Pi /skill:graphify` is expanded by `pi` instead of being
prompted, while built-ins such as `:Pi /settings` are typed into the `pi`
terminal (they only exist in its TUI, so one has to be open).

### Editor niceties

catppuccin-mocha theme, lualine (macro-recording indicator and SSH badge),
which-key, noice + notify, nvim-autopairs, todo-comments, marks.nvim,
mini.files (replaces netrw; deletion moves files to trash instead of removing
them), smear-cursor.

## Custom plugins

These plugins are developed alongside this configuration and are packaged by the
flake:

| Plugin | What it does |
| --- | --- |
| [`net_picker`](https://github.com/sergioia-dev/net_picker) | Picks a listening process or container and kills, signals, tails, restarts, debugs, yanks or jumps to it. Uses the fzf-lua backend here; containers are read over the podman/docker REST socket, falling back to `/proc` |
| [`code-helper-nvim`](https://github.com/sergioia-dev/code-helper-nvim) | `:ConBase64Encode`, `:ConBase64Decode`, `:ConURLEncode`, `:ConURLDecode` and `:GenSecret` conversions |
| [`toggable-term-nvim`](https://github.com/sergioia-dev/toggable-term-nvim) | Focus-aware vertical, horizontal and floating terminal sidebars |
| [`pi-nvim`](https://github.com/carderne/pi-nvim) | Bridge between the `pi` coding agent and Neovim |
| [`vim-dadbod-manager`](https://github.com/sergioia-dev/vim-dadbod-manager-ui) | Server → databases → tables tree for dadbod-ui connections |
| [`nvim-pr`](plugins/nvim-pr) | `:PR` creates, lists, previews, checks out, opens and merges pull requests on GitHub (`gh`), GitLab (`glab`) and Azure DevOps (`az`). Provider is detected from the `origin` remote; the CLIs are only called, never configured |
| [`dbtui`](https://github.com/Di3go0-0/dbtui) | Standalone Rust TUI database client (PostgreSQL, MySQL, SQL Server, Oracle) with encrypted saved connections. Shipped as `.#dbtui`, not part of the Neovim package |
| [`sql-mer-tui`](https://github.com/sergioia-dev/sql-mer-tui) | Keyboard-driven terminal ER diagram (`sqlv`), opened from the vim-dadbod-manager drawer's **Schema viewer** action. Shipped as `.#sql-mer-tui` and put on the Neovim wrapper's `PATH` |

`net_picker` keymaps: `Tab` multi-select, `Enter`/`C-k` kill, `C-s` signal,
`C-t` tail log, `C-r` restart, `C-d` debugger, `C-o` cd, `C-y` yank, `C-g` jump
to source.

### Pull requests (`nvim-pr`)

`:PR` talks to the pull/merge request API of whichever forge `origin` points
at. It shells out to `gh`, `glab` or `az`, so authentication is whatever those
CLIs already have — the plugin never stores a token and never adds one.

| Command | Action |
| --- | --- |
| `:PR` | Pick a pull request; yours sort first, tagged `· yours` |
| `:PR create` | Write the pull request in a scratch markdown buffer |
| `:PR view [id]` | Read-only split: the pull request on top, its conversation below |
| `:checkhealth pr` | Detected provider, repository root and CLI status |

`:PR create` opens a buffer of labelled rows: `Source:`/`Target:` branches,
`Reviewers:`, and `Title:`/`Description:`. Inside it, `t` picks the target
(base) branch from the remote branches, `s` the source (head) branch from the
local ones, and `rr`/`ro` multi-select a required or optional reviewer; the
remote branch list and the provider's people are fetched in the background while
you type, so the menus open without a wait. `<Tab>` on the
`N commits · M files changed` line expands it into the commits it counts, with
`<Tab>` on a commit opening the files it touches; `<C-c><C-c>` creates the pull
request (no confirmation) and `<C-c><C-k>` — or `:q!` — discards it. Nothing
happens on `:w`: the buffer is scratch, and a draft without a title is rejected.
`:checkhealth pr` reports which CLIs are installed and logged in.

Per-provider coverage:

| Action | GitHub | GitLab | Azure DevOps |
| --- | --- | --- | --- |
| create / list / view / open (`gx` in the view) | yes | yes | yes |
| reviewers (`rr`/`ro`) | collaborators via `gh api` | members via `glab api` | users via `az devops user list` |
| draft, delete source branch | yes | yes | yes |

Full details, configuration and the `<Plug>(pr-*)` mappings are in
[`plugins/nvim-pr/README.md`](plugins/nvim-pr/README.md).

## Quick Commands

| Command | Action |
| --- | --- |
| `:Neogit` | Git TUI |
| `:PR` | Pick a pull request (create, view, checkout, open, merge) |
| `:PR create` | Write a pull request in a scratch buffer |
| `<F1>` / `:DBManagerToggle` | Database browser |
| `<leader>fm` | File explorer (mini.files) |
| `<leader>fn` | Network/process picker |
| `<leader>ff` | Find files |
| `<C-w>%` / `<C-w>"` | Right / bottom terminal |
| `:FlutterRun` | Run the Flutter app |
| `:ConBase64Encode` | Base64-encode the selection |

## Keymaps

The leader key is `<Space>`.

### Find and navigate

| Key | Action |
| --- | --- |
| `<leader>ff` | Find files |
| `<leader>fa` | Live grep |
| `<leader><Tab>` | Open buffers |
| `<leader>fi` | Grep inside the current file |
| `<leader>fc` | Todo comments |
| `<leader>fn` | Network/process picker |
| `<leader>m` | Marks |

### LSP

| Key | Action |
| --- | --- |
| `<leader>lr` | References and implementations (Lspsaga finder) |
| `<leader>lR` | Rename |
| `K` | Hover documentation |
| `<leader>lo` | Outline |
| `<leader>lf` | Find functions and variables (treesitter) |
| `<leader>la` | Code action |
| `<leader>le` | Workspace diagnostics |
| `<leader>lq` | Quickfix list |
| `<leader>ls` | Diagnostic float for the current line |
| `<leader>li` | Implementations |

### Git

| Key | Action |
| --- | --- |
| `<leader>gg` | Neogit |
| `<leader>glb` | Toggle inline blame |
| `<leader>gb` | Branches |
| `<leader>gc` | Commits |

### Sidebars and terminals

| Key | Action |
| --- | --- |
| `<F1>` | Toggle the database browser |
| `<leader>fm` | Toggle the mini.files explorer |
| `<C-w>"` | Toggle the bottom terminal |
| `<C-w>%` | Toggle the right terminal |
| `<leader>a` | Toggle the `pi` terminal |
| `<leader>p` | Open the `:Pi` prompt dialog (`:Pi <text>` sends directly) |

### Editing

| Key | Action |
| --- | --- |
| `<C-s>` | Save the file |
| `<Esc>` | Leave terminal mode |

## Prerequisites

- [Nix](https://nixos.org/download.html) installed on your system
- Flakes enabled (add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`)

# Installation

## Via Nix Profile (Recommended)

Install directly from GitHub:

```bash
nix profile add github:sergioia-dev/neovim-nix
```

Or install locally after cloning:

```bash
nix profile add .
```

## As a Flake App

Test without installing:

```bash
nix run github:sergioia-dev/neovim-nix
```

Build the package:

```bash
nix build github:sergioia-dev/neovim-nix
```

## Home Manager Integration

This flake does not currently ship a Home Manager module. You can add the package directly:

```nix
{ inputs, ... }: {
  home.packages = [ inputs.neovim-nix.packages.${pkgs.system}.default ];
}
```

## NixOS Integration

This flake does not currently ship a NixOS module. You can add the package to `environment.systemPackages`:

```nix
{ inputs, ... }: {
  environment.systemPackages = [ inputs.neovim-nix.packages.${pkgs.system}.default ];
}
```

# Usage

Run Neovim:

```bash
nvim
```

The wrapper launches Neovim with `NVIM_APPNAME=nvim-custom`, prepends the
flake's language servers, formatters and CLI tools (`ripgrep`, `git`, `lldb`,
`jq`, `lsof`, `tree-sitter-cli`, `jsregexp`, `fzf`) to `PATH`, and loads the
configuration from the packaged `pack/custom/start` instead of
`~/.config/nvim`. Plugin state and caches therefore live under
`~/.cache/nvim-custom/` and `~/.local/share/nvim-custom/`.

## Local Plugin Edits

The custom plugins live in this repository as git submodules. When you build a
local checkout with `nix build "path:$PWD"`, the flake copies the *committed*
state of each submodule, not your working tree, so uncommitted local edits are
invisible to the build. The exported store path also contains the exact
revision that was copied, which is why the build prints a trace message naming
it.

The submodules are:

- `plugins/project-tree`
- `plugins/net_picker`
- `plugins/code-helper`
- `plugins/toggable-term`
- `plugins/vim-dadbod-manager`

To pick up local plugin edits, commit and push them in the submodule, then bump
the matching `rev` (and, if it changed, `sha256`) in `flake.nix` before
rebuilding.
