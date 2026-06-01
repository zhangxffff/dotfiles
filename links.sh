#!/usr/bin/env bash
# LINKS — the single place to add a new symlink.
# Each entry: "<path relative to repo>|<absolute target>"
#
# Granularity: top-level files are linked per-file; lua/ and conf.d entries are
# directories or per-file so machine-generated siblings can coexist. An entry
# whose source doesn't exist yet is warned-and-skipped by symlink_one, so it's
# safe to pre-list expected configs before migrating them in.
#
# To add a config: drop it under config/ and append one line here.

# fish config lives entirely in conf.d/ drop-in fragments — config.fish itself is
# left unmanaged so installers (rustup/fnm/uv) can append to it without touching
# our files. Fragments load in name order; zz-local-paths runs last (PATH priority).
LINKS=(
  "config/nvim/init.lua|$HOME/.config/nvim/init.lua"
  "config/nvim/lua|$HOME/.config/nvim/lua"
  "config/fish/conf.d/00-locale.fish|$HOME/.config/fish/conf.d/00-locale.fish"
  "config/fish/conf.d/10-bun.fish|$HOME/.config/fish/conf.d/10-bun.fish"
  "config/fish/conf.d/20-venv.fish|$HOME/.config/fish/conf.d/20-venv.fish"
  "config/fish/conf.d/30-zed-tmux.fish|$HOME/.config/fish/conf.d/30-zed-tmux.fish"
  "config/fish/conf.d/fzf.fish|$HOME/.config/fish/conf.d/fzf.fish"
  "config/fish/conf.d/zz-local-paths.fish|$HOME/.config/fish/conf.d/zz-local-paths.fish"
)

run_links() {
  local entry
  for entry in "${LINKS[@]}"; do
    symlink_one "${entry%%|*}" "${entry##*|}"
  done
}
