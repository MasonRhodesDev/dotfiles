# fzf keybindings: Ctrl-T file picker, Alt-C cd. Named 10-* so it loads
# BEFORE atuin.bashrc — both bind Ctrl-R, and atuin must win (last bind).
if [[ ${BLE_VERSION-} ]]; then
    _ble_contrib_fzf_base=/usr/share/fzf
    ble-import integration/fzf-key-bindings
elif [ -f /usr/share/fzf/shell/key-bindings.bash ]; then
    source /usr/share/fzf/shell/key-bindings.bash
fi
