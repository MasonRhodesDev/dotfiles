# Oh My Posh prompt. Skipped (bash's default prompt is the fallback tier) in:
# Cursor/vscode integrated terminals, console/TTY logins (TTY_CONSOLE is
# exported by 00-tty-console.bashrc and survives into tmux, where TERM is no
# longer "linux"), and when the binary isn't installed yet on a fresh machine.
# Also skipped when ble.sh is installed but didn't load (BLE_VERSION unset):
# omp's cached init script (~/.cache/oh-my-posh/init.*.sh) bakes in
# unconditional `bleopt` transient-prompt calls once generated inside a ble.sh
# shell, so evaluating it in a shell without ble — non-TTY interactive shells
# like IDE tasks or `bash -ic` — errors "bleopt: command not found" twice.
if [[ ${TERM_PROGRAM-} != vscode && -z ${TTY_CONSOLE-} && $TERM != linux ]] \
    && { [[ ${BLE_VERSION-} ]] || [[ ! -f ~/.local/share/blesh/ble.sh ]]; } \
    && command -v oh-my-posh >/dev/null; then
    eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/bubbles.omp.json")"
fi
