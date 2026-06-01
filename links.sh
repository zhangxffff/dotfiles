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

# LINKS — one repo path linked to one absolute target (per-file or a whole dir
# as a single symlink). Add a config: drop it under config/, append one line.
LINKS=(
  "config/nvim/init.lua|$HOME/.config/nvim/init.lua"
  "config/nvim/lua|$HOME/.config/nvim/lua"
)

# LINK_DIRS — merge-link: every file in the repo dir is linked into the target
# dir, coexisting with foreign files already there. Use this when our files must
# share a directory with externally-managed ones. fish's conf.d is the case:
# config.fish is left unmanaged so installers (rustup/fnm/uv) can append to it,
# and our fragments live in conf.d/ next to the tool-generated snippets.
# Adding/removing a fragment needs no edit here — link_dir links new files and
# prunes our own orphaned links. Fragments load in name order; zz-local-paths
# runs last (PATH priority).
LINK_DIRS=(
  "config/fish/conf.d|$HOME/.config/fish/conf.d"
)

run_links() {
  local entry
  for entry in "${LINKS[@]}"; do
    symlink_one "${entry%%|*}" "${entry##*|}"
  done
  for entry in "${LINK_DIRS[@]}"; do
    link_dir "${entry%%|*}" "${entry##*|}"
  done
}
