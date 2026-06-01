# Managed by dotfiles repo. Activate the default Python venv if it exists.
# Guarded so a machine without ~/.venv doesn't error on every shell.
test -f ~/.venv/bin/activate.fish; and source ~/.venv/bin/activate.fish
