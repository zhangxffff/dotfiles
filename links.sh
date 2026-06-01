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

LINKS=(
  "config/nvim/init.lua|$HOME/.config/nvim/init.lua"
  "config/nvim/lua|$HOME/.config/nvim/lua"
  "config/fish/config.fish|$HOME/.config/fish/config.fish"
  "config/fish/conf.d/00-local-paths.fish|$HOME/.config/fish/conf.d/00-local-paths.fish"
  "config/fish/conf.d/fzf.fish|$HOME/.config/fish/conf.d/fzf.fish"
  # Enable after migrating the matching installer-generated snippets into the repo:
  # "config/fish/conf.d/rustup.fish|$HOME/.config/fish/conf.d/rustup.fish"
  # "config/fish/conf.d/fnm.fish|$HOME/.config/fish/conf.d/fnm.fish"
  # "config/fish/conf.d/uv.env.fish|$HOME/.config/fish/conf.d/uv.env.fish"
)

run_links() {
  local entry
  for entry in "${LINKS[@]}"; do
    symlink_one "${entry%%|*}" "${entry##*|}"
  done
}
