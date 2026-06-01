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

# --- fnm (node version manager): expose the default node in every shell ---
# We install fnm into ~/.local/bin with --skip-shell, so this is what actually
# puts node/npm on PATH. Guarded on `command -q fnm` (skip if absent) and on
# FNM_DIR being unset (skip if a tool-generated conf.d/fnm.fish already ran it).
command -q fnm; and not set -q FNM_DIR; and fnm env --shell fish | source

# --- fzf shell integration (guarded; needs fzf on PATH, set just above) ---
command -q fzf; and fzf --fish | source

# --- aliases ---
command -q nvim; and alias vim nvim

# --- Zed: attach each directory to its own zellij session (interactive only) ---
# Kept last: PATH is fully configured above before this may exec into zellij.
# `zellij attach --create` is a foreground process (unlike tmux switch-client),
# so exec is safe; $ZELLIJ guards against relaunching inside an existing session.
if status is-interactive; and test "$TERM_PROGRAM" = "Zed"; and not set -q ZELLIJ; and command -q zellij
    set SESSION (basename "$PWD")
    set SESSION (string replace -ra '[^a-zA-Z0-9_.-]' '_' -- $SESSION)
    exec zellij attach --create "$SESSION"
end
