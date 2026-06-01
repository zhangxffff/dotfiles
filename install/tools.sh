#!/usr/bin/env bash
# Per-tool installers. Conventions (keep these when adding a tool):
#   - install_<tool> detects whether the tool is installed:
#       installed  -> run that tool's update path
#       missing    -> fresh install
#   - Call detect_platform and build the asset name from OS/ARCH so one
#     function works on both Linux and macOS (no Homebrew dependency).
#   - NEVER modify PATH and NEVER symlink individual binaries. PATH is handled
#     centrally by config/fish/conf.d/00-local-paths.fish:
#       1. tools we extract to ~/.local/<tool>/current/bin  -> picked up by glob
#       2. tools that land in ~/.local/bin (uv/claude/opencode) -> picked up too
#       3. tools with their own env snippet (rustup/fnm)     -> manage that
#          snippet as a conf.d/*.fish link instead of rewriting PATH here
#   - Official installers are run with "don't touch my shell rc" flags.
#
# Order matters in INSTALLERS: rust before fish (fish 4.x source build needs
# cargo), node before codex (codex is an npm global).
INSTALLERS=(rust fish node nvim claude codex lazygit fzf zellij uv opencode)

# Pinned versions — change in one place. Override via env, e.g. NVIM_VERSION=v0.10.4.
NVIM_VERSION="${NVIM_VERSION:-v0.12.2}"
FISH_VERSION="${FISH_VERSION:-4.0.2}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-v0.44.1}"
FZF_VERSION="${FZF_VERSION:-v0.56.3}"
ZELLIJ_VERSION="${ZELLIJ_VERSION:-v0.44.3}"

# current_points_to <tool> <version> — true if ~/.local/<tool>/current -> <version>.
current_points_to() {
  local link="$HOME/.local/$1/current"
  [[ -L "$link" && "$(basename "$(canonical "$link")")" == "$2" ]]
}

install_rust() {
  if command -v rustup >/dev/null 2>&1; then
    log "rust: updating toolchains"
    rustup update
  else
    require_cmd curl || return 1
    log "rust: installing via rustup (no shell rc changes)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  fi
  "$HOME/.cargo/bin/rustc" --version 2>/dev/null || rustc --version
}

install_fish() {
  if current_points_to fish "$FISH_VERSION"; then
    log "fish $FISH_VERSION already current"
    return 0
  fi
  # rustup installs cargo with --no-modify-path, so on a fresh one-shot run it's
  # not yet on PATH — add it for this build before requiring it.
  [[ -d "$HOME/.cargo/bin" ]] && PATH="$HOME/.cargo/bin:$PATH"
  require_cmd curl tar xz cmake cc cargo || return 1
  log "fish: building $FISH_VERSION from source (this takes a few minutes)"
  local base="$HOME/.local/fish" dest="$HOME/.local/fish/$FISH_VERSION"
  local tmpd
  tmpd="$(mktemp -d)"
  local url="https://github.com/fish-shell/fish-shell/releases/download/$FISH_VERSION/fish-$FISH_VERSION.tar.xz"
  curl -fL -o "$tmpd/fish.tar.xz" "$url"
  tar -xf "$tmpd/fish.tar.xz" -C "$tmpd"
  local srcdir="$tmpd/fish-$FISH_VERSION"
  cmake -S "$srcdir" -B "$srcdir/build" -DCMAKE_INSTALL_PREFIX="$dest"
  cmake --build "$srcdir/build"
  cmake --install "$srcdir/build"
  rm -rf "$tmpd"
  mkdir -p "$base"
  ln -sfn "$FISH_VERSION" "$base/current"
  "$dest/bin/fish" --version
}

install_node() {
  if ! command -v fnm >/dev/null 2>&1; then
    require_cmd curl || return 1
    log "node: installing fnm (no shell rc changes)"
    curl -fsSL https://fnm.vercel.app/install | bash -s -- \
      --install-dir "$HOME/.local/share/fnm" --skip-shell
  fi
  local fnm_bin="$HOME/.local/share/fnm/fnm"
  command -v fnm >/dev/null 2>&1 && fnm_bin="$(command -v fnm)"
  log "node: installing/using LTS via fnm"
  "$fnm_bin" install --lts
  "$fnm_bin" default lts-latest
  "$fnm_bin" exec --using=lts-latest node --version
}

# nvim_url — release URL for the current platform. Requires OS/ARCH
# (detect_platform). v0.11+ asset naming: nvim-<linux|macos>-<x86_64|arm64>.tar.gz
nvim_url() {
  local nos
  case "$OS" in
    linux)  nos=linux ;;
    darwin) nos=macos ;;
  esac
  printf 'https://github.com/neovim/neovim/releases/download/%s/nvim-%s-%s.tar.gz' \
    "$NVIM_VERSION" "$nos" "$ARCH"
}

install_nvim() {
  detect_platform || return 1
  if current_points_to nvim "$NVIM_VERSION"; then
    log "nvim $NVIM_VERSION already current"
    return 0
  fi
  install_versioned nvim "$NVIM_VERSION" "$(nvim_url)" 1 || return 1
  "$HOME/.local/nvim/current/bin/nvim" --version | head -1
}

install_claude() {
  if command -v claude >/dev/null 2>&1; then
    log "claude: updating"
    claude update || true
  else
    require_cmd curl || return 1
    log "claude: installing native build into ~/.local/bin"
    curl -fsSL https://claude.ai/install.sh | bash
  fi
  claude --version 2>/dev/null || true
}

install_codex() {
  require_cmd npm || {
    err "codex needs npm — run: ./setup.sh install node"
    return 1
  }
  if command -v codex >/dev/null 2>&1; then
    log "codex: updating"
    npm install -g @openai/codex@latest
  else
    log "codex: installing"
    npm install -g @openai/codex
  fi
  codex --version 2>/dev/null || true
}

# lazygit_url — release URL for the current platform. Requires OS/ARCH.
# Asset naming: lazygit_<ver>_<Linux|Darwin>_<x86_64|arm64>.tar.gz
lazygit_url() {
  local lgos
  case "$OS" in
    linux)  lgos=Linux ;;
    darwin) lgos=Darwin ;;
  esac
  printf 'https://github.com/jesseduffield/lazygit/releases/download/%s/lazygit_%s_%s_%s.tar.gz' \
    "$LAZYGIT_VERSION" "${LAZYGIT_VERSION#v}" "$lgos" "$ARCH"
}

install_lazygit() {
  detect_platform || return 1
  if current_points_to lazygit "$LAZYGIT_VERSION"; then
    log "lazygit $LAZYGIT_VERSION already current"
    return 0
  fi
  install_single_binary lazygit "$LAZYGIT_VERSION" "$(lazygit_url)" lazygit || return 1
  "$HOME/.local/lazygit/current/bin/lazygit" --version | head -1
}

# fzf_url — release URL for the current platform. Requires OS/ARCH.
# Asset naming: fzf-<ver>-<linux|darwin>_<amd64|arm64>.tar.gz
fzf_url() {
  local fos farch
  case "$OS" in
    linux)  fos=linux ;;
    darwin) fos=darwin ;;
  esac
  case "$ARCH" in
    x86_64) farch=amd64 ;;
    arm64)  farch=arm64 ;;
  esac
  printf 'https://github.com/junegunn/fzf/releases/download/%s/fzf-%s-%s_%s.tar.gz' \
    "$FZF_VERSION" "${FZF_VERSION#v}" "$fos" "$farch"
}

install_fzf() {
  detect_platform || return 1
  if current_points_to fzf "$FZF_VERSION"; then
    log "fzf $FZF_VERSION already current"
    return 0
  fi
  install_single_binary fzf "$FZF_VERSION" "$(fzf_url)" fzf || return 1
  "$HOME/.local/fzf/current/bin/fzf" --version
}

# zellij_url — release URL for the current platform. Requires OS/ARCH.
# Zellij names assets by Rust target triple: zellij-<arch>-<unknown-linux-musl
# |apple-darwin>.tar.gz, where arch is x86_64 or aarch64.
zellij_url() {
  local zarch triple
  case "$ARCH" in
    x86_64) zarch=x86_64 ;;
    arm64)  zarch=aarch64 ;;
  esac
  case "$OS" in
    linux)  triple="${zarch}-unknown-linux-musl" ;;
    darwin) triple="${zarch}-apple-darwin" ;;
  esac
  printf 'https://github.com/zellij-org/zellij/releases/download/%s/zellij-%s.tar.gz' \
    "$ZELLIJ_VERSION" "$triple"
}

install_zellij() {
  detect_platform || return 1
  if current_points_to zellij "$ZELLIJ_VERSION"; then
    log "zellij $ZELLIJ_VERSION already current"
    return 0
  fi
  install_single_binary zellij "$ZELLIJ_VERSION" "$(zellij_url)" zellij || return 1
  "$HOME/.local/zellij/current/bin/zellij" --version
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv: self-update"
    uv self update || true
  else
    require_cmd curl || return 1
    log "uv: installing into ~/.local/bin"
    curl -LsSf https://astral.sh/uv/install.sh | sh
  fi
  uv --version 2>/dev/null || true
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log "opencode: upgrading"
    opencode upgrade || true
  else
    require_cmd curl || return 1
    log "opencode: installing into ~/.local/bin"
    # The env var must reach the installer (bash), not just curl.
    curl -fsSL https://opencode.ai/install | OPENCODE_INSTALL_DIR="$HOME/.local/bin" bash
  fi
  opencode --version 2>/dev/null || true
}

# run_install — install/update the tools in $DOTFILES_TOOLS (space-separated),
# or all of INSTALLERS when that env is unset.
#
# Each tool runs in a subshell with `set -e`, so a single tool failing (a flaky
# download, a missing build dep) is reported and skipped without aborting the
# rest — a one-shot run gets as far as it can. Returns non-zero if any failed.
run_install() {
  local names n rc=0 failed=()
  if [[ -n "${DOTFILES_TOOLS:-}" ]]; then
    # shellcheck disable=SC2206  # intentional word-splitting of the env list
    names=(${DOTFILES_TOOLS})
  else
    names=("${INSTALLERS[@]}")
  fi

  for n in "${names[@]}"; do
    if ! declare -F "install_$n" >/dev/null; then
      err "unknown tool: $n"
      rc=1
      failed+=("$n")
      continue
    fi
    if ! ( set -e; "install_$n" ); then
      err "install failed: $n"
      rc=1
      failed+=("$n")
    fi
  done

  [[ ${#failed[@]} -gt 0 ]] && err "tools failed: ${failed[*]}"
  return "$rc"
}
