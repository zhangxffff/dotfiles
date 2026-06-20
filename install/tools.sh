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
# Order matters in INSTALLERS: node before codex/pi (both are npm globals).
# fish is NOT installed here — it's a prerequisite installed with your system
# package manager (apt/dnf/brew); setup.sh aborts if it's not on PATH.
INSTALLERS=(rust node nvim claude codex pi lazygit fzf zellij treesitter uv opencode)

# Pinned versions — change in one place. Override via env, e.g. NVIM_VERSION=v0.10.4.
NVIM_VERSION="${NVIM_VERSION:-v0.12.2}"
LAZYGIT_VERSION="${LAZYGIT_VERSION:-v0.44.1}"
FZF_VERSION="${FZF_VERSION:-v0.56.3}"
ZELLIJ_VERSION="${ZELLIJ_VERSION:-v0.44.3}"
TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-v0.26.9}"
FNM_VERSION="${FNM_VERSION:-v1.39.0}"

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

# fnm_url — fnm release zip for the current platform (Schniz/fnm). The zip holds
# a single `fnm` binary. We fetch from GitHub releases (reliable) rather than the
# fnm.vercel.app install script, which has 504'd in some regions.
fnm_url() {
  local asset
  case "$OS" in
    linux)
      case "$ARCH" in
        x86_64) asset="fnm-linux.zip" ;;
        arm64)  asset="fnm-arm64.zip" ;;
      esac
      ;;
    darwin) asset="fnm-macos.zip" ;;
  esac
  printf 'https://github.com/Schniz/fnm/releases/download/%s/%s' "$FNM_VERSION" "$asset"
}

install_node() {
  # Locate an existing fnm first (PATH, then our managed location).
  local fnm_bin=""
  if command -v fnm >/dev/null 2>&1; then
    fnm_bin="$(command -v fnm)"
  elif [[ -x "$HOME/.local/bin/fnm" ]]; then
    fnm_bin="$HOME/.local/bin/fnm"
  fi

  if [[ -z "$fnm_bin" ]]; then
    detect_platform || return 1
    require_cmd curl unzip || return 1 # fnm releases ship as a .zip
    log "node: installing fnm $FNM_VERSION from GitHub releases (into ~/.local/bin)"
    local tmpd
    tmpd="$(mktemp -d)"
    if ! curl -fL -o "$tmpd/fnm.zip" "$(fnm_url)"; then
      err "node: failed to download fnm ($(fnm_url))"
      rm -rf "$tmpd"
      return 1
    fi
    if ! unzip -q -o "$tmpd/fnm.zip" fnm -d "$tmpd"; then
      err "node: failed to unzip fnm"
      rm -rf "$tmpd"
      return 1
    fi
    mkdir -p "$HOME/.local/bin"
    mv "$tmpd/fnm" "$HOME/.local/bin/fnm"
    chmod +x "$HOME/.local/bin/fnm"
    rm -rf "$tmpd"
    fnm_bin="$HOME/.local/bin/fnm"
  fi

  # Verify before using, so a failed install gives a clear error (not a cryptic
  # "No such file or directory" from running a missing binary).
  if [[ ! -x "$fnm_bin" ]]; then
    err "node: fnm not found at $fnm_bin after install — aborting node setup"
    return 1
  fi

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
    log "claude: installing native build into ~/.local/bin"
    run_remote_installer claude https://claude.ai/install.sh || return 1
  fi
  claude --version 2>/dev/null || true
}

# load_npm_env — npm-global installers (codex, pi) need npm on PATH. In a
# one-shot run node was just installed via fnm but isn't on this process's PATH
# yet, so load fnm's env. <tool> names the caller for the error message.
load_npm_env() {
  local tool="$1"
  if ! command -v npm >/dev/null 2>&1; then
    local fnm_bin="$HOME/.local/bin/fnm"
    [[ -x "$fnm_bin" ]] || fnm_bin="$(command -v fnm 2>/dev/null || true)"
    if [[ -n "$fnm_bin" ]]; then
      eval "$("$fnm_bin" env 2>/dev/null)" 2>/dev/null || true
    fi
  fi
  require_cmd npm || {
    err "$tool needs npm — run ./setup.sh with node enabled first"
    return 1
  }
}

install_codex() {
  load_npm_env codex || return 1
  if command -v codex >/dev/null 2>&1; then
    log "codex: updating"
    npm install -g @openai/codex@latest
  else
    log "codex: installing"
    npm install -g @openai/codex
  fi
  codex --version 2>/dev/null || true
}

# install_pi — the Pi coding agent CLI (binary: pi), an npm global. The official
# pi.dev/install.sh prompts interactively and edits shell rc with no opt-out, so
# we install via npm to keep PATH centralized and the one-shot run unattended.
# --ignore-scripts per upstream guidance (pi needs no install lifecycle scripts).
install_pi() {
  load_npm_env pi || return 1
  if command -v pi >/dev/null 2>&1; then
    log "pi: updating"
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent@latest
  else
    log "pi: installing"
    npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  fi
  pi --version 2>/dev/null || true
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

# treesitter_url — the tree-sitter CLI release asset is a bare gzipped binary
# (NOT a tarball), named tree-sitter-<linux|macos>-<x64|arm64>.gz.
treesitter_url() {
  local tsos tsarch
  case "$OS" in
    linux)  tsos=linux ;;
    darwin) tsos=macos ;;
  esac
  case "$ARCH" in
    x86_64) tsarch=x64 ;;
    arm64)  tsarch=arm64 ;;
  esac
  printf 'https://github.com/tree-sitter/tree-sitter/releases/download/%s/tree-sitter-%s-%s.gz' \
    "$TREE_SITTER_VERSION" "$tsos" "$tsarch"
}

# treesitter_cargo_fallback — build the CLI from source with cargo and link it
# into the managed dir. Used when the prebuilt binary won't run here (its glibc
# requirement can be newer than an older distro provides).
treesitter_cargo_fallback() {
  local base="$1" dest="$2"
  local cargo_bin="$HOME/.cargo/bin/cargo"
  command -v cargo >/dev/null 2>&1 && cargo_bin="$(command -v cargo)"
  if [[ ! -x "$cargo_bin" ]]; then
    err "treesitter: prebuilt CLI won't run and cargo is unavailable — install rust first (./setup.sh)"
    return 1
  fi
  log "treesitter: building tree-sitter-cli via cargo (a few minutes)"
  "$cargo_bin" install tree-sitter-cli --version "${TREE_SITTER_VERSION#v}" \
    || "$cargo_bin" install tree-sitter-cli || return 1
  mkdir -p "$dest/bin"
  ln -sf "$HOME/.cargo/bin/tree-sitter" "$dest/bin/tree-sitter"
  ln -sfn "$(basename "$dest")" "$base/current"
  log "treesitter current -> $(basename "$dest") (cargo)"
  "$dest/bin/tree-sitter" --version
}

# install_treesitter — the tree-sitter CLI, required by nvim-treesitter's main
# branch to build parsers. Installed as treesitter/current/bin/tree-sitter so the
# PATH glob picks it up. Prefer the prebuilt binary (bare .gz, so gunzip); if it
# can't run here (e.g. its glibc is too new for this distro), build via cargo.
install_treesitter() {
  detect_platform || return 1
  if current_points_to treesitter "$TREE_SITTER_VERSION"; then
    log "tree-sitter CLI $TREE_SITTER_VERSION already current"
    return 0
  fi
  require_cmd curl gzip || return 1
  local base="$HOME/.local/treesitter" dest="$HOME/.local/treesitter/$TREE_SITTER_VERSION"
  log "installing tree-sitter CLI $TREE_SITTER_VERSION"
  local tmpd
  tmpd="$(mktemp -d)"
  if curl -fL -o "$tmpd/ts.gz" "$(treesitter_url)"; then
    mkdir -p "$dest/bin"
    gzip -dc "$tmpd/ts.gz" > "$dest/bin/tree-sitter"
    chmod +x "$dest/bin/tree-sitter"
    rm -rf "$tmpd"
    # Verify the prebuilt binary actually runs on this system before committing.
    if "$dest/bin/tree-sitter" --version >/dev/null 2>&1; then
      ln -sfn "$TREE_SITTER_VERSION" "$base/current"
      log "treesitter current -> $TREE_SITTER_VERSION (prebuilt)"
      "$dest/bin/tree-sitter" --version
      return 0
    fi
    warn "treesitter: prebuilt binary won't run here (likely glibc too old) — falling back to cargo"
    rm -rf "${dest:?}/bin"
  else
    rm -rf "$tmpd"
    warn "treesitter: prebuilt download failed — falling back to cargo"
  fi
  treesitter_cargo_fallback "$base" "$dest"
}

install_uv() {
  if command -v uv >/dev/null 2>&1; then
    log "uv: self-update"
    uv self update || true
  else
    log "uv: installing into ~/.local/bin"
    run_remote_installer uv https://astral.sh/uv/install.sh || return 1
  fi
  uv --version 2>/dev/null || true
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log "opencode: upgrading"
    opencode upgrade || true
  else
    log "opencode: installing into ~/.local/bin"
    INSTALLER_ENV="OPENCODE_INSTALL_DIR=$HOME/.local/bin" \
      run_remote_installer opencode https://opencode.ai/install || return 1
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
