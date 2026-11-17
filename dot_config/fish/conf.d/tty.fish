status is-interactive; or exit
set -l vt (tty)
string match -qr '^/dev/tty[0-9]+$' $vt; or exit

for pair in 012131a 1e78284 2a5d6a7 3e5c890 48aadf4 5c6a0f6 68bd5ca 7c5c5d6 \
            8565866 9ffb4ab ac8e6c9 bffecb3 cadcbfa dd0bcff ea6e3e0 fe3e1ec
    printf '\e]P%s' $pair
end
clear
setterm -blank 0 -powersave off 2>/dev/null

set -gx TTY_CONSOLE 1

function _tty_tier --argument-names grace label
    set -l t0 (date +%s)
    $argv[3..]
    set -l rc $status
    test (math (date +%s) - $t0) -ge $grace; and exec true
    echo "tty: $label died within $grace sec (exit $rc) — degrading" >&2
end

if test "$vt" = /dev/tty2; and not set -q tty_no_gui
    and command -q cage; and command -q kitty
    _tty_tier 5 cage+kitty cage -s -- kitty
end

if not set -q TMUX; and not set -q tty_no_tmux; and command -q tmux
    _tty_tier 2 tmux tmux -L vt new-session -A -s (string replace '/dev/' '' $vt)
end
