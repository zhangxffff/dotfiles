# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal dotfiles: nvim + fish configs symlinked from this repo, plus a bash
installer that puts tools under `~/.local`. Cross-platform (Linux + macOS) with
no Homebrew dependency — release assets are selected from `uname`.

## Commands

```sh
./setup.sh                                  # link configs, then install/update all tools (idempotent)
DOTFILES_TOOLS="nvim fzf zellij" ./setup.sh # scope the install set (linking always runs in full)
NVIM_VERSION=v0.10.4 ./setup.sh             # override a pinned version (see install/tools.sh)
```

`setup.sh` takes no arguments. It hard-requires fish on `PATH` (aborts with an
error if missing) — fish is a prerequisite the repo does not install.

Lint / check before pushing (this is exactly what CI runs):

```sh
shellcheck setup.sh lib/common.sh links.sh install/tools.sh
bash -n   setup.sh lib/common.sh links.sh install/tools.sh
```

There is no test runner — CI (`.github/workflows/ci.yml`) is the test suite: it
runs the real `./setup.sh` against the runner's `$HOME` on Linux + macOS,
asserts links/backups/`current` symlinks, **re-runs to prove idempotency**, and
headlessly bootstraps the nvim plugins. When changing install or link logic,
mirror the assertion you'd add into that workflow.

## Architecture

`setup.sh` sources three files in order and calls `run_links` then `run_install`:

- **`lib/common.sh`** — the engine. Logging, `detect_platform` (sets `OS`/`ARCH`
  globals consumed by installers), `canonical` (portable realpath), `symlink_one`,
  `run_remote_installer` (downloads a `curl|sh` installer to a tempfile and
  rejects HTML error pages before executing), and the two release-archive helpers
  `install_versioned` / `install_single_binary`.
- **`links.sh`** — the `LINKS` array, the single place to register a symlink.
  Each entry is `"<repo path>|<absolute target>"`. To add a config: drop a file
  under `config/` and append one line.
- **`install/tools.sh`** — one `install_<tool>` function per tool, the
  `INSTALLERS` order list, and pinned `*_VERSION` vars. `run_install` runs each
  tool in a `set -e` subshell so one failure is reported and skipped without
  aborting the rest.

### Two invariants that hold the design together

1. **PATH lives in exactly one place.** `config/fish/conf.d/zz-dotfiles.fish`
   owns PATH order: it globs `~/.local/*/current/bin` and prepends each (plus
   `~/.local/bin`) with `fish_add_path --prepend --move`. The `zz-` prefix makes
   it load **last** in `conf.d`, after tool-generated snippets (fnm/rustup/uv),
   so its priority block wins. Installers must **never** touch PATH or symlink
   individual binaries. (Note: some code comments still reference an older
   `00-local-paths.fish` name — the live file is `zz-dotfiles.fish`.)

2. **Versioned tools use a `current` symlink for atomic upgrade/rollback.**
   `install_versioned` / `install_single_binary` extract to
   `~/.local/<tool>/<version>/bin` and flip `~/.local/<tool>/current -> <version>`.
   Upgrading only re-points the symlink; the old version stays for rollback.
   `current_points_to` is the idempotency check that skips an already-current tool.
   Tools installed by their own official installer (uv/claude/opencode → `~/.local/bin`,
   rust → rustup, node → fnm) don't follow this layout — they detect→update.

**Adding a tool:** write `install_<name>` in `install/tools.sh` following the
detect→update / else-install convention (reuse `install_versioned` or
`install_single_binary` for release archives, build the asset URL from
`OS`/`ARCH`), then add the name to `INSTALLERS`. Order matters: `node` before
`codex` (codex is an npm global).

**fish is not installed by this repo** — install it with your system package
manager (apt/dnf/brew). `setup.sh` checks for it up front and aborts if it's
missing (the managed fish config is useless without the shell).

### Fish config is a single conf.d fragment

All fish config is one file, `config/fish/conf.d/zz-dotfiles.fish`, **not**
`config.fish`. `config.fish` is left unmanaged so tool installers (rustup/fnm/uv)
can append to it without clobbering our config, and owning a single `zz-`-prefixed
`conf.d` entry means one stable link with no orphaned-link pruning.

### nvim

`config/nvim/init.lua` → `lua/config/lazy.lua` bootstraps lazy.nvim on first
launch (auto-clones it, no committed `lazy-lock.json` needed) and imports
`lua/plugins/`. The leader is set **before** lazy loads. GitHub Copilot is wired
in (inline ghost text + blink-cmp-copilot); `:Copilot auth` once to sign in. The
`treesitter` installer provides the tree-sitter CLI that nvim-treesitter's `main`
branch needs to build parsers.

## Build prerequisites the installers do not install for you

These surface as a clear error naming the missing command: `unzip` (node/fnm),
and a C compiler (treesitter / nvim parser builds). Debian/Ubuntu:
`sudo apt install unzip build-essential`.
