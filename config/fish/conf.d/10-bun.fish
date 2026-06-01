# Managed by dotfiles repo. bun runtime.
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path --global --prepend $BUN_INSTALL/bin
