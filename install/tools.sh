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
INSTALLERS=(rust fish node nvim claude codex lazygit fzf uv opencode)

# Pinned versions — change in one place. Override via env, e.g. NVIM_VERSION=v0.10.4.
NVIM_VERSION="${NVIM_VERSION:-v0.12.2}"
FISH_VERSION="${FISH_VERSION:-4.0.2}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-v0.44.1}"
FZF_VERSION="${FZF_VERSION:-v0.56.3}"

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
  require_cmd curl tar xz cmake cc || return 1
  command -v cargo >/dev/null 2>&1 || {
    err "fish build needs cargo — run: ./setup.sh install rust"
    return 1
  }
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

install_nvim() {
  detect_platform || return 1
  if current_points_to nvim "$NVIM_VERSION"; then
    log "nvim $NVIM_VERSION already current"
    return 0
  fi
  local nos
  case "$OS" in
    linux)  nos=linux ;;
    darwin) nos=macos ;;
  esac
  # v0.11+ asset naming: nvim-<linux|macos>-<x86_64|arm64>.tar.gz
  local asset="nvim-${nos}-${ARCH}.tar.gz"
  local url="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$asset"
  install_versioned nvim "$NVIM_VERSION" "$url" 1 || return 1
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

install_lazygit() {
  detect_platform || return 1
  if current_points_to lazygit "$LAZYGIT_VERSION"; then
    log "lazygit $LAZYGIT_VERSION already current"
    return 0
  fi
  local lgos
  case "$OS" in
    linux)  lgos=Linux ;;
    darwin) lgos=Darwin ;;
  esac
  local asset="lazygit_${LAZYGIT_VERSION#v}_${lgos}_${ARCH}.tar.gz"
  local url="https://github.com/jesseduffield/lazygit/releases/download/$LAZYGIT_VERSION/$asset"
  install_single_binary lazygit "$LAZYGIT_VERSION" "$url" lazygit || return 1
  "$HOME/.local/lazygit/current/bin/lazygit" --version | head -1
}

install_fzf() {
  detect_platform || return 1
  if current_points_to fzf "$FZF_VERSION"; then
    log "fzf $FZF_VERSION already current"
    return 0
  fi
  local fos farch
  case "$OS" in
    linux)  fos=linux ;;
    darwin) fos=darwin ;;
  esac
  case "$ARCH" in
    x86_64) farch=amd64 ;;
    arm64)  farch=arm64 ;;
  esac
  local asset="fzf-${FZF_VERSION#v}-${fos}_${farch}.tar.gz"
  local url="https://github.com/junegunn/fzf/releases/download/$FZF_VERSION/$asset"
  install_single_binary fzf "$FZF_VERSION" "$url" fzf || return 1
  "$HOME/.local/fzf/current/bin/fzf" --version
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
    OPENCODE_INSTALL_DIR="$HOME/.local/bin" curl -fsSL https://opencode.ai/install | bash
  fi
  opencode --version 2>/dev/null || true
}

# run_install [names...] — install/update the named tools, or all of INSTALLERS.
run_install() {
  local names=("$@") n
  [[ ${#names[@]} -eq 0 ]] && names=("${INSTALLERS[@]}")
  for n in "${names[@]}"; do
    if declare -F "install_$n" >/dev/null; then
      "install_$n"
    else
      err "unknown tool: $n"
    fi
  done
}
