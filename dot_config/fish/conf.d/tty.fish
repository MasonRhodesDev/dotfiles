# Pure-TTY (linux virtual console) niceties. Whole file no-ops unless this
# is an interactive shell directly on /dev/ttyN — inside tmux/pts it skips.
# System side (Terminus font, gpm, initramfs) is run_onchange_after_55.
status is-interactive; or exit
string match -qr '^/dev/tty[0-9]+$' (tty); or exit

# 16-color palette via linux-console OSC P. Hand-tuned around the lmtt dark
# theme's bg/fg, but with true hues for the semantic slots (red/green/blue/
# cyan) — the lmtt-generated terminal palette maps those to non-semantic
# material tones, which makes ls/pacman/error output unreadable on a VT.
for pair in 012131a 1e78284 2a5d6a7 3e5c890 48aadf4 5c6a0f6 68bd5ca 7c5c5d6 \
            8565866 9ffb4ab ac8e6c9 bffecb3 cadcbfa dd0bcff ea6e3e0 fe3e1ec
    printf '\e]P%s' $pair
end
clear  # repaint so existing cells pick up the new palette

# No screen blanking / powersave on the console
setterm -blank 0 -powersave off 2>/dev/null

# The kernel dropped VT scrollback (5.9) — tmux is the scrollback. One
# session per VT. Escape hatch: `set -U tty_no_tmux 1` to get a bare shell.
if not set -q TMUX; and not set -q tty_no_tmux; and command -q tmux
    exec tmux new-session -A -s (string replace '/dev/' '' (tty))
end
