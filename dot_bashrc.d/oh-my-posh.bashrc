# Oh My Posh prompt. Skipped (bash's default prompt is the fallback tier) in:
# Cursor/vscode integrated terminals, console/TTY logins (TTY_CONSOLE is
# exported by 00-tty-console.bashrc and survives into tmux, where TERM is no
# longer "linux"), and when the binary isn't installed yet on a fresh machine.
if [[ ${TERM_PROGRAM-} != vscode && -z ${TTY_CONSOLE-} && $TERM != linux ]] \
    && command -v oh-my-posh >/dev/null; then
    eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/bubbles.omp.json")"
fi
