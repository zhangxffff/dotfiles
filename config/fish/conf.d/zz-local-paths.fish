# Managed by dotfiles repo. Makes ~/.local take priority on PATH.
#
# The zz- prefix makes this load LAST in conf.d (after fnm/rustup/uv snippets),
# and config.fish is intentionally unmanaged/empty, so nothing re-prepends after
# this — ~/.local stays at the front of PATH.
#
# Every tool we install lives at ~/.local/<tool>/current/bin — prepend each so
# repo-installed tools win over system copies. Adding a new tool needs no edit
# here; the glob picks it up.
for d in $HOME/.local/*/current/bin
    fish_add_path --global --prepend --move $d
end

# Fallback for tools that install straight into ~/.local/bin (uv, claude, opencode).
fish_add_path --global --prepend --move $HOME/.local/bin
