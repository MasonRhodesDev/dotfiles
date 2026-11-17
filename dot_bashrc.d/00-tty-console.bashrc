[[ $- == *i* ]] || return 0
_vt=$(tty)
if [[ ! $_vt =~ ^/dev/tty[0-9]+$ ]]; then
    unset _vt
    return 0
fi

for _pair in 012131a 1e78284 2a5d6a7 3e5c890 48aadf4 5c6a0f6 68bd5ca 7c5c5d6 \
             8565866 9ffb4ab ac8e6c9 bffecb3 cadcbfa dd0bcff ea6e3e0 fe3e1ec; do
    printf '\e]P%s' "$_pair"
done
unset _pair
clear
setterm -blank 0 -powersave off 2>/dev/null

export TTY_CONSOLE=1

_tty_tier() {
    local grace=$1 label=$2 t0 rc
    t0=$(date +%s)
    shift 2
    "$@"
    rc=$?
    (( $(date +%s) - t0 >= grace )) && exec true
    echo "tty: $label died within ${grace}s (exit $rc) — degrading" >&2
}

if [[ $_vt == /dev/tty2 && ! -e ~/.config/tty-no-gui ]] \
    && command -v cage >/dev/null && command -v kitty >/dev/null; then
    _rt=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
    mkdir -pm700 "$_rt/tty-cage"
    _tty_tier 5 cage+kitty env XDG_RUNTIME_DIR="$_rt/tty-cage" \
        cage -s -- kitty -o "env=XDG_RUNTIME_DIR=$_rt" -o "env=WAYLAND_DISPLAY=" \
                         -o update_check_interval=0
    unset _rt
fi

if [[ -z ${TMUX-} && ! -e ~/.config/tty-no-tmux ]] && command -v tmux >/dev/null; then
    _tty_tier 2 tmux tmux -L vt new-session -A -s "${_vt#/dev/}"
fi

unset _vt
