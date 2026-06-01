# Managed by dotfiles repo — all our fish config in a single conf.d fragment.
#
# Why one file: it's the only conf.d entry we own, so linking is one stable
# entry and there are no orphaned links to prune. config.fish is left unmanaged
# so installers (rustup/fnm/uv) can append to it without touching this.
#
# Why the zz- prefix: conf.d loads in name order, so this runs LAST — after the
# tool-generated fnm/rustup/uv snippets — which is what lets the PATH-priority
# block below win.

# --- locale (C.UTF-8 on Linux; stock macOS lacks it, use en_US.UTF-8 there) ---
if test (uname) = Darwin
    set -gx LANG en_US.UTF-8
else
    set -gx LANG C.UTF-8
end
set -gx LC_ALL $LANG
set -gx LC_CTYPE $LANG

# --- build parallelism (nproc on Linux, sysctl on macOS) ---
if command -q nproc
    set -gx CI_NUM_THREADS (nproc)
else
    set -gx CI_NUM_THREADS (sysctl -n hw.ncpu)
end

# --- bun ---
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path --global --prepend $BUN_INSTALL/bin

# --- python venv (guarded so a machine without ~/.venv doesn't error) ---
test -f ~/.venv/bin/activate.fish; and source ~/.venv/bin/activate.fish

# --- PATH priority: make ~/.local win over everything set above and by tools ---
# Each tool we install lives at ~/.local/<tool>/current/bin; the glob picks up
# new ones with no edit. ~/.local/bin is the fallback for single-binary installs.
for d in $HOME/.local/*/current/bin
    fish_add_path --global --prepend --move $d
end
fish_add_path --global --prepend --move $HOME/.local/bin

# --- fzf shell integration (guarded; needs fzf on PATH, set just above) ---
command -q fzf; and fzf --fish | source

# --- Zed: attach each directory to its own tmux session (interactive only) ---
# Kept last: PATH is fully configured above before this may exec into tmux.
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
