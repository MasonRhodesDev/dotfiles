# direnv: load .envrc files on cd (nix-shell, per-project env). Moved out of
# ~/.bashrc so non-interactive login shells skip the hook install.
[[ $- == *i* ]] || return 0
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
