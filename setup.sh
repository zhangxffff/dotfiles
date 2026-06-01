#!/usr/bin/env bash
# Dotfiles entry point.
#   ./setup.sh link            # symlink managed configs into place
#   ./setup.sh install [names] # install/update tools into ~/.local (default: all)
#   ./setup.sh all             # link + install everything
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$DOTFILES_DIR/lib/common.sh"
# shellcheck source=links.sh
source "$DOTFILES_DIR/links.sh"
# shellcheck source=install/tools.sh
source "$DOTFILES_DIR/install/tools.sh"

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

case "$cmd" in
  link)    run_links ;;
  install) run_install "$@" ;;
  all)     run_links; run_install ;;
  *)
    echo "usage: ./setup.sh [link | install [names...] | all]"
    exit 1
    ;;
esac
