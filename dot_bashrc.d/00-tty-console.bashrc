# Pure-TTY (linux virtual console) setup. VTs are DISASTER RECOVERY: every
# tier below must FAIL THROUGH to the next, degrading until we hit a raw
# kernel console. Never `exec` a tier here — a broken tier must not kill the
# login. (Port of the retired fish conf.d/tty.fish.)
#
#   tty2 : cage+kitty GUI terminal (ligatures)  -> tmux -> raw shell
#   tty3+: tmux (scrollback)                    -> raw shell
#   raw  : kernel console, ASCII prompt (oh-my-posh.bashrc skips whenever
#          TTY_CONSOLE is set or TERM=linux)
#
# Opt-outs when you already know a tier is wedged (fish used universal vars;
# bash has none, so these are flag files):
#   touch ~/.config/tty-no-gui    skip cage/kitty on tty2
#   touch ~/.config/tty-no-tmux   skip tmux everywhere
#
# Whole file no-ops unless this is an interactive shell directly on
# /dev/ttyN — inside tmux/pts it skips. System side (Terminus font, gpm,
# initramfs) is chezmoi run_onchange_after_55.
[[ $- == *i* ]] || return 0
_vt=$(tty)
if [[ ! $_vt =~ ^/dev/tty[0-9]+$ ]]; then
    unset _vt
    return 0
fi

# --- console comfort: zero-dependency escape codes, safe at every tier ---
# 16-color palette via linux-console OSC P. Hand-tuned around the lmtt dark
# theme's bg/fg, but with true hues for the semantic slots (red/green/blue/
# cyan) — the lmtt-generated terminal palette maps those to non-semantic
# material tones, which makes ls/pacman/error output unreadable on a VT.
for _pair in 012131a 1e78284 2a5d6a7 3e5c890 48aadf4 5c6a0f6 68bd5ca 7c5c5d6 \
             8565866 9ffb4ab ac8e6c9 bffecb3 cadcbfa dd0bcff ea6e3e0 fe3e1ec; do
    printf '\e]P%s' "$_pair"
done
unset _pair
clear  # repaint so existing cells pick up the new palette
setterm -blank 0 -powersave off 2>/dev/null

# Mark every shell in this login (including ones tmux spawns, which see
# TERM=screen-*, not linux) as console-hosted → plain ASCII prompt.
export TTY_CONSOLE=1

# A tier that survived startup was a real session: log out when it ends,
# whatever its exit code (kiosk semantics — quitting kitty must close the
# TTY). Only a fast death is a wedged tier that falls through. Exit codes
# alone can't tell "GPU wedge" from "kitty quit nonzero", but time can.
# NB: `return` in a sourced file only aborts this file, leaving a live shell
# behind — ending the login for real requires replacing the process, hence
# `exec true`.
_tty_tier() {
    local grace=$1 label=$2 t0 rc
    t0=$(date +%s)
    shift 2
    "$@"
    rc=$?
    (( $(date +%s) - t0 >= grace )) && exec true
    echo "tty: $label died within ${grace}s (exit $rc) — degrading" >&2
}

# --- tier 1, tty2 only: real terminal emulator on bare DRM --------------
# Ligatures/nerd glyphs need a shaping engine the kernel console will never
# have. cage -s: VT switching is disabled by default (kiosk hardening) and
# must be allowed explicitly or Ctrl+Alt+F# is swallowed.
if [[ $_vt == /dev/tty2 && ! -e ~/.config/tty-no-gui ]] \
    && command -v cage >/dev/null && command -v kitty >/dev/null; then
    _tty_tier 5 cage+kitty cage -s -- kitty
fi

# --- tier 2: tmux for scrollback (kernel VTs have none since 5.9) --------
# Dedicated socket (-L vt): tmux children inherit the SERVER's env, so
# attaching to a GUI-born default server would drop TTY_CONSOLE and bring
# oh-my-posh glyphs back to the console. The vt server is always born from
# a VT login. Rescuing GUI tmux sessions still works: `tmux attach` inside
# here reaches the default socket.
if [[ -z ${TMUX-} && ! -e ~/.config/tty-no-tmux ]] && command -v tmux >/dev/null; then
    _tty_tier 2 tmux tmux -L vt new-session -A -s "${_vt#/dev/}"
fi

# --- tier 3: raw kernel console — you are here, nothing else to fail -----
unset _vt
