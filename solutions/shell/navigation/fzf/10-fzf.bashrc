[[ $- == *i* ]] || return 0
if [[ ${BLE_VERSION-} ]]; then
    _ble_contrib_fzf_base=@fzf@
    ble-import integration/fzf-key-bindings
elif [ -f @fzf@/key-bindings.bash ]; then
    source @fzf@/key-bindings.bash
fi
