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

# LINKS — one repo path linked to one absolute target (a file, or a whole dir as
# a single symlink). Add a config: drop it under config/, append one line.
#
# All our fish config is a single conf.d fragment (zz-dotfiles.fish) rather than
# many files, so it's one stable entry here with no orphaned links to manage.
# config.fish is left unmanaged so installers (rustup/fnm/uv) can append to it,
# and the zz- prefix makes our fragment load last (PATH priority).
LINKS=(
  "config/nvim/init.lua|$HOME/.config/nvim/init.lua"
  "config/nvim/lua|$HOME/.config/nvim/lua"
  "config/fish/conf.d/zz-dotfiles.fish|$HOME/.config/fish/conf.d/zz-dotfiles.fish"
)

run_links() {
  local entry
  for entry in "${LINKS[@]}"; do
    symlink_one "${entry%%|*}" "${entry##*|}"
  done
}
