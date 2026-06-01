# Managed by dotfiles repo. Load fzf's fish key bindings & completions.
# Guarded so a fish session without fzf installed doesn't error.
command -q fzf; and fzf --fish | source
