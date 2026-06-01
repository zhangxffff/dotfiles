#!/usr/bin/env bash
# Common helpers for the dotfiles setup engine.
# Sourced by setup.sh (and transitively by links.sh / install/tools.sh).

# Guard against double-sourcing.
[[ -n "${_COMMON_SH:-}" ]] && return 0
_COMMON_SH=1

# Resolve DOTFILES_DIR if setup.sh didn't already set it (e.g. when a helper
# file is sourced directly). lib/ is one level below the repo root.
if [[ -z "${DOTFILES_DIR:-}" ]]; then
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# ---- logging -------------------------------------------------------------
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_BLUE=$'\033[34m'; _C_YELLOW=$'\033[33m'; _C_RED=$'\033[31m'
else
  _C_RESET=''; _C_BLUE=''; _C_YELLOW=''; _C_RED=''
fi

log()  { printf '%s[dotfiles]%s %s\n' "$_C_BLUE" "$_C_RESET" "$*"; }
warn() { printf '%s[dotfiles]%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*"; }
err()  { printf '%s[dotfiles]%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }

# ---- prerequisites -------------------------------------------------------
# require_cmd <cmd...> — return non-zero (and report) if any command is missing.
require_cmd() {
  local missing=0 c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      err "required command not found: $c"
      missing=1
    fi
  done
  return "$missing"
}

# detect_platform — set OS (linux|darwin) and ARCH (x86_64|arm64) globals.
# Installers build their download asset names from these (see install/tools.sh).
# shellcheck disable=SC2034  # OS/ARCH are consumed by install/tools.sh after sourcing.
detect_platform() {
  local s m
  s="$(uname -s)"
  m="$(uname -m)"
  case "$s" in
    Linux)  OS=linux ;;
    Darwin) OS=darwin ;;
    *) err "unsupported OS: $s"; return 1 ;;
  esac
  case "$m" in
    x86_64 | amd64)  ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=arm64 ;;
    *) err "unsupported arch: $m"; return 1 ;;
  esac
  return 0
}

# canonical <path> — portable realpath. `readlink -f` is GNU-only (stock macOS
# lacks -f), so fall back to realpath / python3 / a pure-shell resolution.
canonical() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null && return 0
  fi
  if [[ -d "$p" ]]; then
    (cd "$p" && pwd -P)
  else
    local d b
    d="$(cd "$(dirname "$p")" 2>/dev/null && pwd -P)" || return 1
    b="$(basename "$p")"
    printf '%s/%s\n' "$d" "$b"
  fi
}

# ---- installer helpers ---------------------------------------------------
# Layout for tools we install ourselves:
#   ~/.local/<tool>/<version>/bin/...   (the extracted release)
#   ~/.local/<tool>/current -> <version> (symlink we flip atomically)
# PATH is handled centrally by config/fish/conf.d/00-local-paths.fish, which
# globs ~/.local/*/current/bin — so these helpers never touch PATH.

# install_versioned <tool> <version> <url> <strip_components>
# For release tarballs that already contain a bin/ directory (e.g. nvim).
install_versioned() {
  local tool="$1" version="$2" url="$3" strip="${4:-1}"
  require_cmd curl tar || return 1
  local base="$HOME/.local/$tool"
  local dest="$base/$version"
  if [[ -d "$dest" ]]; then
    log "$tool $version already present"
  else
    log "installing $tool $version"
    local tmpd
    tmpd="$(mktemp -d)"
    curl -fL -o "$tmpd/archive" "$url"
    mkdir -p "$tmpd/extract"
    tar -xf "$tmpd/archive" -C "$tmpd/extract" --strip-components="$strip"
    mkdir -p "$base"
    mv "$tmpd/extract" "$dest"
    rm -rf "$tmpd"
  fi
  ln -sfn "$version" "$base/current"
  log "$tool current -> $version"
}

# install_single_binary <tool> <version> <url> <binary_name_in_archive>
# For tarballs that are just a bare binary (e.g. lazygit, fzf).
install_single_binary() {
  local tool="$1" version="$2" url="$3" binname="$4"
  require_cmd curl tar || return 1
  local base="$HOME/.local/$tool"
  local dest="$base/$version"
  if [[ -d "$dest" ]]; then
    log "$tool $version already present"
  else
    log "installing $tool $version"
    local tmpd
    tmpd="$(mktemp -d)"
    curl -fL -o "$tmpd/archive.tar.gz" "$url"
    tar -xf "$tmpd/archive.tar.gz" -C "$tmpd"
    mkdir -p "$dest/bin"
    mv "$tmpd/$binname" "$dest/bin/$tool"
    chmod +x "$dest/bin/$tool"
    rm -rf "$tmpd"
  fi
  ln -sfn "$version" "$base/current"
  log "$tool current -> $version"
}

# ---- symlinking ----------------------------------------------------------
# symlink_one <repo-relative-path> <absolute-target>
# Idempotent. Backs up a pre-existing real file/dir before linking. A missing
# source is warned-and-skipped (returns 0 so `set -e` callers keep going).
symlink_one() {
  local rel="$1" target="$2"
  local src="$DOTFILES_DIR/$rel"

  if [[ ! -e "$src" ]]; then
    warn "source missing: $rel — skipping"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    if [[ "$(canonical "$target")" == "$(canonical "$src")" ]]; then
      log "skip (already linked): $target"
      return 0
    fi
    # Wrong symlink — fall through to replace it.
  elif [[ -e "$target" ]]; then
    local backup
    backup="$target.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    log "backed up existing $target -> $backup"
  fi

  ln -sfn "$src" "$target"
  log "linked $target -> $src"
}

# link_dir <repo-relative-dir> <absolute-target-dir>
# Merge-link a whole directory: symlink every file in the repo dir into the
# target dir, alongside whatever else lives there (e.g. tool-generated fish
# conf.d snippets). Use this instead of listing each file in LINKS so adding or
# removing a file needs no edit:
#   - new files in the repo dir get linked automatically;
#   - our own orphaned links (pointing back into this repo dir but whose source
#     is gone, e.g. a renamed/deleted fragment) get pruned.
# Foreign regular files in the target dir are never touched.
link_dir() {
  local rel="$1" target_dir="$2"
  local src_dir="$DOTFILES_DIR/$rel"

  if [[ ! -d "$src_dir" ]]; then
    warn "source dir missing: $rel — skipping"
    return 0
  fi
  mkdir -p "$target_dir"

  # Prune orphaned symlinks we previously created from this repo dir.
  local link dest
  for link in "$target_dir"/*; do
    [[ -L "$link" ]] || continue
    dest="$(readlink "$link")"
    case "$dest" in
      "$src_dir"/*)
        if [[ ! -e "$dest" ]]; then
          rm "$link"
          log "pruned orphaned link: $link"
        fi
        ;;
    esac
  done

  # Link every file currently in the repo dir.
  local f
  for f in "$src_dir"/*; do
    [[ -e "$f" ]] || continue
    symlink_one "$rel/$(basename "$f")" "$target_dir/$(basename "$f")"
  done
}
