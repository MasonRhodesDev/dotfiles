[[ $- == *i* ]] || return 0
if [[ -z ${CLAUDECODE-} ]] && command -v chezmoi >/dev/null; then
    _cz_drift=${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-drift
    if [[ -s $_cz_drift/status ]]; then
        printf 'chezmoi drift (%s file(s)): %s — see `chezmoi diff`\n' \
            "$(wc -l < "$_cz_drift/status")" \
            "$(awk '{print $2}' "$_cz_drift/status" | paste -sd' ' - | cut -c1-160)"
    fi
    if [[ ! -e $_cz_drift/stamp || $(( $(date +%s) - $(stat -c %Y "$_cz_drift/stamp") )) -ge 21600 ]]; then
        mkdir -p "$_cz_drift"
        touch "$_cz_drift/stamp"
        ( { chezmoi status --exclude=scripts 2>/dev/null > "$_cz_drift/status.new" &&
            mv -f "$_cz_drift/status.new" "$_cz_drift/status"; } & )
    fi
    unset _cz_drift
fi
