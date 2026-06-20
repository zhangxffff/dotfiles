# dotfiles

Personal dotfiles: nvim + fish configs symlinked from this repo, and a small
installer that puts tools under `~/.local`. Works on Linux and macOS (no
Homebrew dependency — release assets are chosen by `uname`).

## Usage

```sh
./setup.sh
```

One shot: it symlinks the managed configs into `~/.config`, then installs/updates
the tools into `~/.local`. Safe to re-run — already-linked configs and
already-current tool versions are detected and skipped, and a tool that fails
(flaky download, missing build dep) is reported without aborting the rest.

**fish is a prerequisite** — this repo manages fish config but does not install
the shell. Install it with your package manager first (`sudo apt install fish`,
`brew install fish`, …); `setup.sh` aborts immediately if fish isn't on `PATH`.
Setting fish as your login shell is up to you (`chsh -s (which fish)`).

To scope the install set (linking always runs in full):

```sh
DOTFILES_TOOLS="nvim fzf zellij" ./setup.sh
```

## Layout

```
setup.sh            entry point
lib/common.sh       engine: logging, symlink_one, detect_platform, install helpers
links.sh            LINKS array — the one place to register a new symlink
install/tools.sh    install_<tool> functions + run_install
config/             the actual config files, symlinked into place
  nvim/             init.lua + lua/ (config/lazy.lua bootstrap + plugins/)
  fish/conf.d/      zz-dotfiles.fish (config.fish is left unmanaged on purpose)
```

All our fish config lives in a single conf.d fragment,
`conf.d/zz-dotfiles.fish`, rather than in `config.fish` — so installers that
append to `config.fish` (rustup/fnm/uv) never touch our config, and it's the
only conf.d file we own (no per-file link list, no orphaned links). The `zz-`
prefix makes it load last in `conf.d`, after the tool-generated snippets, so its
PATH-priority block wins.

## How it works

### Linking

`run_links` (`links.sh`) feeds each `LINKS` entry to `symlink_one`, which:

- skips entries whose source doesn't exist yet (warn, exit 0);
- skips targets already pointing at the repo (idempotent);
- backs up a pre-existing real file/dir to `<target>.bak.<timestamp>` before
  replacing it (gitignored);
- creates the symlink.

Each `LINKS` entry is `"<repo path>|<absolute target>"` — a file, or a whole
directory linked as a single symlink. **Add a config:** drop the file under
`config/`, append one line. Our fish config is one fragment
(`config/fish/conf.d/zz-dotfiles.fish`), so it's a single stable entry that
shares `~/.config/fish/conf.d/` with tool-generated files without colliding.

### Installing

Each tool is detected first: if already installed it runs that tool's *update*
path, otherwise a fresh install. Tools we fetch as release archives are
version-pinned at `~/.local/<tool>/<version>` with a `current` symlink that's
flipped atomically — so upgrades keep the old version around for rollback.

Built-in installers: `rust node nvim claude codex lazygit fzf zellij treesitter uv opencode`.
(fish itself is not installed here — use your system package manager; `./setup.sh
fish` only sets an already-installed fish as your login shell.)
Versions are env-overridable, e.g. `NVIM_VERSION=v0.10.4 ./setup.sh`.
(`treesitter` installs the tree-sitter CLI, which nvim-treesitter's `main` branch
needs to build parsers.)

A few installers need system tools that aren't installed for you (you'll get a
clear error naming the missing one): `unzip` for **node** (the fnm installer),
and a C compiler for **treesitter**/nvim parser builds. On Debian/Ubuntu:
`sudo apt install unzip build-essential`.

**Add a tool:** add an `install_<name>` function in `install/tools.sh` (follow
the detect→update / else install convention; reuse `install_versioned` or
`install_single_binary` for release archives), and add the name to `INSTALLERS`.

### PATH

The PATH-priority block in `config/fish/conf.d/zz-dotfiles.fish` is the single
source of PATH order. The `zz-` prefix loads the fragment last in `conf.d`,
after the installer snippets, and `config.fish` is unmanaged so nothing
re-prepends afterwards. It `--prepend --move`s every `~/.local/*/current/bin`
plus `~/.local/bin` to the front of PATH, so repo-installed tools shadow system
ones. Upgrading a tool only flips its `current` symlink — PATH is untouched.

nvim note: `lua/config/lazy.lua` bootstraps lazy.nvim on first launch (auto-clones
it and installs plugins), so a fresh machine needs no `lazy-lock.json`. GitHub
Copilot is wired in (inline ghost text via copilot.lua, plus completion-menu
items via blink-cmp-copilot) — run `:Copilot auth` once to sign in.
