# Chezmoi drift nag: desktop churn (mimeapps.list rewrites, app-edited
# configs) silently diverges live files from chezmoi source between applies —
# 5 drifted files piled up unnoticed by 2026-08-03. At most once per 6h a
# background `chezmoi status` refreshes a state file; every interactive shell
# prints one line while drift exists. Clear it by reconciling: `chezmoi diff`,
# then `chezmoi add <file>` (live is right) or `chezmoi apply <target>`
# (source is right).
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
        # ( … & ) double-fork: no job-table entry, so no "[1]+ Done" noise
        ( { chezmoi status --exclude=scripts 2>/dev/null > "$_cz_drift/status.new" &&
            mv -f "$_cz_drift/status.new" "$_cz_drift/status"; } & )
    fi
    unset _cz_drift
fi
