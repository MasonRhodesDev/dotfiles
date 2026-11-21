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

if [[ ${BLE_VERSION-} ]] && declare -F __bp_adjust_histcontrol >/dev/null; then
    __bp_adjust_histcontrol() { :; }
fi
