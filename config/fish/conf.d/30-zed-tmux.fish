# Managed by dotfiles repo. Inside Zed's integrated terminal, attach to a
# per-directory tmux session. Guarded to interactive shells only (conf.d is
# sourced for all shells, unlike the old config.fish placement).
if status is-interactive; and test "$TERM_PROGRAM" = "Zed"
    set SESSION (basename "$PWD")
    set SESSION (string replace -ra '[^a-zA-Z0-9_.-]' '_' -- $SESSION)
    if set -q TMUX
        # already in tmux → switch session
        exec tmux switch-client -t "$SESSION" 2>/dev/null; or exec tmux new-session -A -s "$SESSION"
    else
        exec tmux new-session -A -s "$SESSION"
    end
end
