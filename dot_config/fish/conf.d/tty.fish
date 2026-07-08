# Pure-TTY (linux virtual console) setup. VTs are DISASTER RECOVERY: every
# tier below must FAIL THROUGH to the next, degrading until we hit a raw
# kernel console. Never `exec` here — a broken tier must not kill the login.
#
#   tty2 : cage+kitty GUI terminal (ligatures)  -> tmux -> raw shell
#   tty3+: tmux (scrollback)                    -> raw shell
#   raw  : kernel console, ASCII prompt (config.fish skips oh-my-posh
#          whenever TTY_CONSOLE is set or TERM=linux)
#
# Opt-outs when you already know a tier is wedged:
#   set -U tty_no_gui 1    skip cage/kitty on tty2
#   set -U tty_no_tmux 1   skip tmux everywhere
#
# Whole file no-ops unless this is an interactive shell directly on
# /dev/ttyN — inside tmux/pts it skips. System side (Terminus font, gpm,
# initramfs) is run_onchange_after_55.
status is-interactive; or exit
set -l vt (tty)
string match -qr '^/dev/tty[0-9]+$' $vt; or exit

# --- console comfort: zero-dependency escape codes, safe at every tier ---
# 16-color palette via linux-console OSC P. Hand-tuned around the lmtt dark
# theme's bg/fg, but with true hues for the semantic slots (red/green/blue/
# cyan) — the lmtt-generated terminal palette maps those to non-semantic
# material tones, which makes ls/pacman/error output unreadable on a VT.
for pair in 012131a 1e78284 2a5d6a7 3e5c890 48aadf4 5c6a0f6 68bd5ca 7c5c5d6 \
            8565866 9ffb4ab ac8e6c9 bffecb3 cadcbfa dd0bcff ea6e3e0 fe3e1ec
    printf '\e]P%s' $pair
end
clear  # repaint so existing cells pick up the new palette
setterm -blank 0 -powersave off 2>/dev/null

# Mark every shell in this login (including ones tmux spawns, which see
# TERM=screen-*, not linux) as console-hosted → plain ASCII prompt.
set -gx TTY_CONSOLE 1

# --- tier 1, tty2 only: real terminal emulator on bare DRM --------------
# Ligatures/nerd glyphs need a shaping engine the kernel console will never
# have. Clean exit (quit kitty) logs out; failure (GPU/seat wedge) falls
# through to tmux with the error left visible above the prompt.
if test "$vt" = /dev/tty2; and not set -q tty_no_gui
    and command -q cage; and command -q kitty
    cage -- kitty
    and exit
    echo "tty: cage+kitty failed — degrading to tmux console" >&2
end

# --- tier 2: tmux for scrollback (kernel VTs have none since 5.9) --------
# Clean exit/detach logs out; failure falls through to the raw shell.
if not set -q TMUX; and not set -q tty_no_tmux; and command -q tmux
    tmux new-session -A -s (string replace '/dev/' '' $vt)
    and exit
    echo "tty: tmux failed — raw shell" >&2
end

# --- tier 3: raw kernel console — you are here, nothing else to fail -----
