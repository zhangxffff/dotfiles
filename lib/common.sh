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

# run_remote_installer <description> <url> [args...] — run a `curl | sh`-style
# installer safely. Downloads it to a temp file and sanity-checks that it's
# actually a script before executing: a region block or outage often returns an
# HTML page with HTTP 200, which piped into a shell yields "syntax error near
# unexpected token '<'". On a bad payload it warns and returns non-zero so the
# caller can skip cleanly. Args after the URL are passed to the script; set
# INSTALLER_ENV="VAR=val" to export one variable for it.
#
# Runs under bash, not sh: several of these installers (e.g. opencode) are bash
# scripts that use bashisms like [[ ]]. Under a POSIX sh (dash on Debian) those
# fail with "[[: not found" and the arch detection misfires ("Unsupported
# OS/Arch"). bash is always present here (setup.sh runs under it) and executes
# the POSIX-sh installers (uv/claude) fine too.
run_remote_installer() {
  local desc="$1" url="$2"; shift 2
  require_cmd curl bash || return 1
  local tmpf
  tmpf="$(mktemp)"
  if ! curl -fsSL -o "$tmpf" "$url"; then
    err "$desc: download failed ($url)"
    rm -f "$tmpf"
    return 1
  fi
  if head -c 512 "$tmpf" | grep -qiE '<!doctype|<html|<head|App unavailable'; then
    err "$desc: installer URL returned a web page, not a script (region-blocked or down?) — skipping"
    rm -f "$tmpf"
    return 1
  fi
  local rc=0
  if [[ -n "${INSTALLER_ENV:-}" ]]; then
    env "$INSTALLER_ENV" bash "$tmpf" "$@" || rc=$?
  else
    bash "$tmpf" "$@" || rc=$?
  fi
  rm -f "$tmpf"
  return "$rc"
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
