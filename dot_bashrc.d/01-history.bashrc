# Shell history. bash's own history feeds up-arrow, prefix search and the
# ble.sh autosuggestions; atuin (Ctrl-R) keeps its own database and is not
# affected by any of this. Interactive shells only.
[[ $- == *i* ]] || return 0

HISTSIZE=200000
HISTFILESIZE=400000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
HISTIGNORE='ls:ll:la:l:cd:cd -:cd ..:pwd:exit:clear:history:bg:fg:jobs:reset'
shopt -s histappend  # append, never truncate, when several shells share the file
shopt -s cmdhist     # multi-line commands are one history entry
shopt -s lithist     # ... kept with their newlines, not joined with semicolons
shopt -s histverify  # a !! or !$ expansion is shown before it runs

# /etc/profile.d/wezterm.sh installs bash-preexec and, at the first prompt,
# strips "ignorespace" out of HISTCONTROL so it can read space-prefixed
# commands back from history for its preexec hook. Under ble.sh the hooks are
# driven by ble itself and never read history, so the rewrite only costs us
# the leading-space-hides-a-command convention. Neuter it there.
if [[ ${BLE_VERSION-} ]] && declare -F __bp_adjust_histcontrol >/dev/null; then
    __bp_adjust_histcontrol() { :; }
fi
