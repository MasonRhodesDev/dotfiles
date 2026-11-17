[[ $- == *i* ]] || return 0

HISTSIZE=200000
HISTFILESIZE=400000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT='%F %T  '
HISTIGNORE='ls:ll:la:l:cd:cd -:cd ..:pwd:exit:clear:history:bg:fg:jobs:reset'
shopt -s histappend
shopt -s cmdhist
shopt -s lithist
shopt -s histverify

if [[ ${BLE_VERSION-} ]] && declare -F __bp_adjust_histcontrol >/dev/null; then
    __bp_adjust_histcontrol() { :; }
fi
