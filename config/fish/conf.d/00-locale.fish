# Managed by dotfiles repo. Locale + build parallelism.
set -gx LANG C.UTF-8
set -gx LC_ALL C.UTF-8
set -gx LC_CTYPE C.UTF-8

# Use the actual core count (portable) instead of a hard-coded number.
set -gx CI_NUM_THREADS (nproc)
