[[ $- == *i* ]] || return 0
if [[ ${TERM_PROGRAM-} != vscode && -z ${TTY_CONSOLE-} && $TERM != linux ]] \
    && { [[ ${BLE_VERSION-} ]] || [[ ! -f ~/.local/share/blesh/ble.sh ]]; } \
    && command -v oh-my-posh >/dev/null; then
    eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/bubbles.omp.json")"
fi
