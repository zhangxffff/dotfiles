#!/usr/bin/env bash
# Dotfiles entry point — one shot does everything, and is safe to re-run:
#   ./setup.sh
#
# It symlinks the managed configs into ~/.config, then installs/updates the
# tools into ~/.local. Re-running is idempotent: already-linked configs and
# already-current tool versions are detected and skipped.
#
# To scope the install set (e.g. in CI), set DOTFILES_TOOLS to a space-separated
# list, e.g. DOTFILES_TOOLS="nvim fzf" ./setup.sh — linking always runs in full.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=links.sh
source "$DOTFILES_DIR/links.sh"
# shellcheck source=install/tools.sh
source "$DOTFILES_DIR/install/tools.sh"

run_links
run_install
