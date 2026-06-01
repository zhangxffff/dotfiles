# Managed by dotfiles repo. Makes ~/.local take priority on PATH.
#
# Every tool we install lives at ~/.local/<tool>/current/bin — prepend each so
# repo-installed tools win over system copies. Adding a new tool needs no edit
# here; the glob picks it up. The 00- prefix loads this early in conf.d.
for d in $HOME/.local/*/current/bin
    fish_add_path --global --prepend --move $d
end

# Fallback for tools that install straight into ~/.local/bin (uv, claude, opencode).
fish_add_path --global --prepend --move $HOME/.local/bin
