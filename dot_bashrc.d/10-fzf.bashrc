[[ $- == *i* ]] || return 0
if [[ ${BLE_VERSION-} ]]; then
    _ble_contrib_fzf_base=/usr/share/fzf
    ble-import integration/fzf-key-bindings
elif [ -f /usr/share/fzf/shell/key-bindings.bash ]; then
    source /usr/share/fzf/shell/key-bindings.bash
fi
