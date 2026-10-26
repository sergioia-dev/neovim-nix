# nvim-pr

Pull requests without leaving Neovim: create, list, view, check out, open in the
browser and merge — for GitHub, GitLab and Azure DevOps.

The plugin is a thin wrapper around the CLIs you already use. It never stores
tokens and never asks for credentials: it detects the provider from
`git remote get-url origin` and then calls whichever of `gh`, `glab` or `az`
the repository needs. Authentication stays wherever those CLIs keep it.

## Requirements

- Neovim 0.10 or newer (`vim.system`, `vim.ui.select`).
- `git` on `PATH`.
- One of the CLIs below, installed and already logged in:

| Provider | CLI | Minimum version | Login |
| --- | --- | --- | --- |
| GitHub | `gh` | 2.0 | `gh auth login` |
| GitLab | `glab` | 1.30 | `glab auth login` |
| Azure DevOps | `az` (with the `azure-devops` extension) | 2.30 | `az login` |

Nothing in this plugin installs or configures the CLIs. `:checkhealth pr`
reports which ones are missing and which ones are not logged in.

## Which repository

The pull request always belongs to one repository, and that repository is
resolved in this order:

1. The root of Neovim's working directory (`git rev-parse --show-toplevel`),
   so `:cd` into a subdirectory still targets the right project.
2. If the working directory is not in a git repository, the root of the file in
   the current buffer.
3. If neither exists, nothing is detected and the commands refuse to run.

`origin` of that repository decides the provider: the host is matched against
the `hosts` list of every enabled provider (`github.com` → `gh`,
`gitlab.com` → `glab`, `dev.azure.com` → `az`). The repository itself is never
guessed by the plugin — `gh` and `glab` resolve owner/name from `origin`
themselves, and for Azure the organization, project and repository are parsed
from the `origin` URL.

Every CLI call runs with the repository root as its working directory, so the
target does not depend on where Neovim happened to be started. `:PR provider`
and `:checkhealth pr` both print the root and the origin they will use, which
is the quickest way to confirm you are about to open a pull request against the
repository you meant.

## Setup

```lua
require("pr").setup({
  -- Optional. Detected from the origin remote when nil.
  default_provider = nil,
  ui = { picker = "fzf-lua" }, -- or "select" to use vim.ui.select
  providers = {
    github = { enabled = true, hosts = { "github.com" } },
    gitlab = { enabled = true, hosts = { "gitlab.com" } },
    azure = { enabled = true, hosts = { "dev.azure.com", "visualstudio.com" } },
  },
  -- No leader mappings are set by default; bind what you want.
  mappings = {
    create = "<leader>gpc",
    list = "<leader>gpl",
  },
})
```

Add extra hosts (a self-hosted GitLab, for example) to the `hosts` list of that
provider. Hosts match exactly or as a suffix, so `"example.com"` also matches
`git.example.com`.

## Commands

| Command | Action |
| --- | --- |
| `:PR` / `:PR list [--state open\|closed\|merged\|all] [--author USER] [--limit N]` | Pick a pull request |
| `:PR create [--title T] [--body B] [--head BRANCH] [--base BRANCH] [--reviewers A,B] [--draft]` | Open the draft buffer |
| `:PR view [id]` | Floating preview of a pull request |
| `:PR checkout <id>` | Check the branch out locally |
| `:PR open [id]` | Open it in the browser |
| `:PR merge <id> [--method merge\|squash\|rebase] [--delete-branch]` | Merge after a confirmation |
| `:PR provider` | Show the detected provider and CLI status |
| `:checkhealth pr` | Everything the plugin knows about your setup |

Every subcommand that takes an `id` falls back to a picker when it is omitted,
so `:PR view` alone shows the open pull requests first.

## Creating a pull request
`:PR create` opens a scratch markdown buffer:

```markdown
# Target Branch: feature/retry -> origin/main

**3 commits · 5 files changed**

| Reviewer | Optional | Required |
| --- | --- | --- |
| @alice | x | |
| @bob | | x |

## Title
Add a retry to the fetch helper

### Description
Retries twice before failing.

# --- 
# <C-c><C-c>          create the pull request
# <C-c><C-k>          discard it
# bt                  pick the target branch (right side): where it will merge
# bc                  pick the source branch (left side): the one to be merged
# br                  pick reviewers for the table above
# <Tab>               list the commits; Tab on one shows the files it touches
```

Write the title under `## Title` and the description under `### Description`.
`# ---` and everything below it is help text and is never submitted.

The `**N commits · M files changed**` line under `# Target Branch:` is a preview
of the merge, not part of the request: the commits come from
`git rev-list --count <target>..<base>` and the files from
`git diff --name-only <target>...<base>`, so work the target already has is not
counted twice. It is recomputed whenever `bt` or `bc` changes a branch. A branch
picked from `bt` is asked from the remote itself, so `origin/topic` counts even
when the clone never fetched it: the remote's tip is used as long as that commit
is already here, without fetching anything. It stays
`**… commits · … files changed**` only when the branch (or its commit) cannot be
found locally at all. It is never sent to the provider, and deleting the line
breaks nothing.

Put the cursor on that line and press `Tab` to expand it into the commits it
counts: one `- <sha> <subject>` row per commit. `Tab` on one of those commits
opens the files it touches, indented under it, and `Tab` on it again — or on any
of its file rows — folds just that commit away. `Tab` on the summary line folds
the whole list away. The rows are ordinary text below the summary line, so the
provider never sees them, and the list is dropped on its own when `bt` or `bc`
changes a branch, because it no longer describes the merge. Nothing is
truncated: a branch of 200 commits lists 200 commits, and a commit that touches
90 files lists 90 files.

| Key | Action |
| --- | --- |
| `<C-c><C-c>` | Create the pull request (the only submit path, no confirmation) |
| `<C-c><C-k>` | Discard the draft; `:q!` does the same |
| `bt` | Pick the **target** branch from the `origin` remote branches, asked live from the remote, so no `git fetch` is needed first: the one it will be merged into (right side) |
| `bc` | Pick the **source** branch from the local branches: the one to be merged (left side) |
| `br` | Pick reviewers: multi-select of the provider's people plus a `➕ Add a handle…` entry, then mark them Optional or Required; the rows are added to the table |
| `<Tab>` | On the `**N commits · M files changed**` line: expand the commits it counts, or fold the list away. On a commit row: show every file that commit touches, or hide them again |

The `bt` list comes from `git ls-remote --heads origin`, so branches pushed by
anyone show up even in a clone that has not fetched since; if that call fails
(offline, bad credentials) it falls back to the local `origin/*` refs. The one
cost is a second of waiting while the remote answers.

The `bt` list is spelled the way git spells remote refs (`origin/main`,
`origin/test`, ...), so there is no guessing which side a branch lives on. The
`origin/` prefix is only cosmetic: it is stripped again when the CLI argv is
built, so `gh` receives `--base main` and not `--base origin/main`.

Both pickers write back into the `# Target Branch:` line, which reads
`<source> -> <target>`: the branch that wants to be merged on the left, the branch
it will be merged into on the right. That whole line is what gets submitted, so
edit it by hand if you prefer. A draft
with no title is rejected and the buffer stays open, so nothing is lost.
`:w` means nothing here: the buffer is scratch (`nofile`), and the pull request
is only created by `<C-c><C-c>`.

Branches (git flags in parentheses, because the words are used the way this
plugin's buffer uses them):

- **Base** — the branch that wants to be merged, left side of the line, picked
  with `bc`. Sent as `--head` (`--source-branch` on GitLab/Azure), else the
  current branch.
- **Target** — the branch it will be merged into, right side of the line, picked
  with `bt`. Sent as `--base` (`--target-branch` on GitLab/Azure), else
  `config.default_base`, else the remote default branch
  (`git ls-remote --symref origin HEAD`, then `main`, then `master`).

`--title` and `--body` pre-fill the draft; `--head` and `--base` pre-populate the
`# Target Branch:` line; `--draft` and `--reviewers A,B` are sent on submit.

## Reviewers

The table below the commit/file summary is the reviewer list. It has three
columns and one row per person; an `x` in `Optional` or `Required` says which kind
that reviewer is:

```markdown
| Reviewer | Optional | Required |
| --- | --- | --- |
| @alice | x | |
| @bob | | x |
```

- The table starts as a bare header and separator, with no rows: `br` adds them,
  or type a row by hand (keep the pipes) and it is read like any other.
- `br` asks the provider who the candidates are, multi-selects, then asks
  `Optional` / `Required` for the whole batch and appends the rows.
- The rows are plain markdown: delete a row to drop that reviewer, or move the
  `x` between the two columns to flip `Optional` ↔ `Required`.
- `br` is always a picker, even when the candidate list cannot be fetched (no
  auth, no permission, no org context, API error): it then opens with the
  `➕ Add a handle…` entry alone and a warning is shown. That entry is how a
  handle the provider does not know is typed in (comma separated for several).
- Candidate sources per provider: `gh api repos/{owner}/{repo}/collaborators`
  (logins), `glab api projects/:id/members/all` (usernames), and
  `az devops user list` (unique names, needs the organization context).

**Limitation:** none of the three CLIs can mark a reviewer as optional or
required through their create/merge flags, so every row — `Optional` and
`Required` alike — is sent on the same reviewer flag and the repository's own
approval rules decide what that means. The column is an annotation for you and
your reviewers, not a policy the plugin can enforce. On Azure the handles must
be emails or identities the organization knows; a wrong handle makes
`az repos pr create` fail rather than silently skip the person.

## Mappings

The plugin exposes `<Plug>` mappings and leaves the keys to you:

| `<Plug>` mapping | Command |
| --- | --- |
| `<Plug>(pr-create)` | `:PR create` |
| `<Plug>(pr-list)` | `:PR list` |
| `<Plug>(pr-view)` | `:PR view` |
| `<Plug>(pr-checkout)` | `:PR checkout` |
| `<Plug>(pr-open)` | `:PR open` |
| `<Plug>(pr-merge)` | `:PR merge` |

`mappings` in `setup()` binds them for you:

```lua
mappings = {
  create = "<leader>gpc",
  list = "<leader>gpl",
  view = "<leader>gpv",
}
```

Or bind them yourself:

```lua
vim.keymap.set("n", "<leader>gpl", "<Plug>(pr-list)", { remap = true, desc = "Pull requests" })
```

## What works per provider

| Action | GitHub (`gh`) | GitLab (`glab`) | Azure DevOps (`az`) |
| --- | --- | --- | --- |
| create | ✅ `gh pr create` | ✅ `glab mr create` | ✅ `az repos pr create` |
| list | ✅ `gh pr list --json` | ✅ `glab mr list --output json` | ✅ `az repos pr list` |
| view | ✅ `gh pr view --json` | ✅ `glab mr view --output json` | ✅ `az repos pr show` |
| checkout | ✅ `gh pr checkout` | ✅ `glab mr checkout` | ⚠️ fetches `refs/pull/<id>/head` and runs `git switch`; on a failed fetch it retries `refs/pull/<id>/merge`. A stale local `pr-<id>` branch is reused |
| open | ✅ | ✅ | ✅ |
| merge | ✅ merge/squash/rebase | ✅ merge/squash/rebase | ⚠️ merge (completes the PR) and squash only |
| draft create | ✅ | ✅ | ✅ |
| reviewers | ✅ `--reviewer` per row | ✅ `--reviewer` per row | ✅ `--reviewers` list; emails/identities only |
| delete source branch | ✅ `--delete-branch` | ✅ `--remove-source-branch` | ✅ `--delete-source-branch` |

Differences the plugin hides for you:

- `--base` becomes `--target-branch` on GitLab and Azure, `--body` becomes
  `--description`, and Azure takes `--organization`, `--project` and
  `--repository` parsed from a `dev.azure.com/<org>/<project>/_git/<repo>`
  remote (falling back to `az devops configure` defaults). Percent-escapes in
  the remote are decoded first, because az wants the project name as it is
  written (`419%20-%20DEPOSITOS` → `419 - DEPOSITOS JUDICIALES`). Only
  `pr create` and `pr list` accept `--project` and `--repository` — `pr show`
  and `pr update` take the organization alone and reject the others as
  `unrecognized arguments`, so the plugin passes each subcommand only what it
  accepts. If those flags make az answer `404`, the command is retried once
  with `--detect true`, which has az work the context out from the git remote
  itself; if that fails too, the error lists every command that was tried.
- Azure refuses a second pull request between the same two branches
  (`TF401179`). The plugin looks the active one up and says so, with its URL,
  instead of echoing the error code.
- Azure cannot rebase a pull request through the CLI; `--method rebase` fails
  with a message that says so instead of silently doing something else.
- All CLIs are called with the flags that keep them non-interactive
  (`--no-editor`, `--yes`, an explicit empty body), so an async call can never
  hang on a prompt.

## Not in this version

Inline diff review, comment threads, CI status, reviewer threads and Azure
Boards work items are out of scope. Required-vs-optional reviewer approval rules
cannot be set through the CLIs either (see [Reviewers](#reviewers)). Use the
browser (`:PR open`) for those.
