# dotfiles

Personal dotfiles: nvim + fish configs symlinked from this repo, and a small
installer that puts tools under `~/.local`. Works on Linux and macOS (no
Homebrew dependency — release assets are chosen by `uname`).

## Usage

```sh
./setup.sh link              # symlink managed configs into ~/.config
./setup.sh install [names]   # install/update tools into ~/.local (default: all)
./setup.sh all               # link + install everything
```

`install` with no names installs everything in dependency order; or name a
subset, e.g. `./setup.sh install nvim fzf`.

## Layout

```
setup.sh            entry point
lib/common.sh       engine: logging, symlink_one, detect_platform, install helpers
links.sh            LINKS array — the one place to register a new symlink
install/tools.sh    install_<tool> functions + run_install
config/             the actual config files, symlinked into place
  nvim/             init.lua + lua/ (config/lazy.lua bootstrap + plugins/)
  fish/conf.d/      drop-in fragments (config.fish is left unmanaged on purpose)
```

fish config is kept entirely in `conf.d/*.fish` fragments rather than
`config.fish`, so installers that append to `config.fish` (rustup/fnm/uv) never
touch our files. Fragments load in filename order; `zz-local-paths.fish` runs
last so its PATH priority wins.

## How it works

### Linking (`./setup.sh link`)

`symlink_one` reads each `LINKS` entry (`"<repo path>|<absolute target>"`) and:

- skips entries whose source doesn't exist yet (warn, exit 0);
- skips targets already pointing at the repo (idempotent);
- backs up a pre-existing real file/dir to `<target>.bak.<timestamp>` before
  replacing it (gitignored);
- creates the symlink.

`links.sh` has two arrays:

- `LINKS` — one repo path → one target (a file, or a whole directory as a single
  symlink). **Add a config:** drop the file under `config/`, append one line.
- `LINK_DIRS` — *merge-link* a directory: every file in the repo dir is linked
  into the target dir, coexisting with foreign files already there (used for
  fish `conf.d`, which also holds tool-generated snippets). Here you **don't**
  edit `links.sh` to add/remove a fragment — `link_dir` links new files and
  prunes our own orphaned links (a leftover symlink into the repo whose source
  was renamed/deleted). Foreign regular files are never touched.

### Installing (`./setup.sh install`)

Each tool is detected first: if already installed it runs that tool's *update*
path, otherwise a fresh install. Tools we fetch as release archives are
version-pinned at `~/.local/<tool>/<version>` with a `current` symlink that's
flipped atomically — so upgrades keep the old version around for rollback.

Built-in installers: `rust fish node nvim claude codex lazygit fzf uv opencode`.
Versions are env-overridable, e.g. `NVIM_VERSION=v0.10.4 ./setup.sh install nvim`.

**Add a tool:** add an `install_<name>` function in `install/tools.sh` (follow
the detect→update / else install convention; reuse `install_versioned` or
`install_single_binary` for release archives), and add the name to `INSTALLERS`.

### PATH

`config/fish/conf.d/zz-local-paths.fish` (managed + linked) is the single source
of PATH priority. The `zz-` prefix loads it last in `conf.d`, after the
installer snippets, and `config.fish` is unmanaged/empty so nothing re-prepends
afterwards. It `--prepend --move`s every `~/.local/*/current/bin` plus
`~/.local/bin` to the front of PATH, so repo-installed tools shadow system ones.
Upgrading a tool only flips its `current` symlink — PATH is untouched.

nvim note: `lua/config/lazy.lua` bootstraps lazy.nvim on first launch (auto-clones
it and installs plugins), so a fresh machine needs no `lazy-lock.json`.
