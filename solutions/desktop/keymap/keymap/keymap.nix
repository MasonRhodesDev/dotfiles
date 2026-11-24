let
  bind = hypr: desc: aerospace: { inherit hypr desc aerospace; };
  skip = hypr: desc: unsupported: { inherit hypr desc unsupported; };
  fnKey = hypr: desc: chord: run: { inherit hypr desc; mac = { inherit chord run; }; };
  macKey = chord: desc: run: { inherit desc; mac = { inherit chord run; }; };
  stock = chord: desc: does: { inherit desc; mac = { inherit chord does; }; };
  workspaces = builtins.genList (i: toString (i + 1)) 9;
  directions = [ "left" "right" "up" "down" ];
  media = "macOS handles media and brightness keys itself";

  backlight = step: "osascript -l JavaScript ~/.hammerspoon/keyboard-backlight.js ${step}";
  snip = ''d=~/Pictures/Screenshots; mkdir -p "$d"; f="$d/Screenshot $(date '+%Y-%m-%d %H.%M.%S').png"; screencapture -i "$f" && [ -s "$f" ] && open -a Preview "$f"'';

  zone = action: ''exec-and-forget ws=$(aerospace list-workspaces --focused); n=''${ws%z}; case $n in *[!0-9]*|"") exit 0 ;; esac; ${action}'';
in
[
  (bind "SUPER + Q" "Apps: Terminal" "exec-and-forget open -na kitty")
  (bind "SUPER + C" "Windows: Close window" "close")
  (bind "SUPER + E" "Apps: File manager" "exec-and-forget open -a Finder")
  (bind "SUPER + V" "Windows: Toggle floating" "layout floating tiling")
  (skip "SUPER + SHIFT + V" "Windows: Pin (show on all workspaces)" "AeroSpace cannot pin a window")
  (bind "SUPER + R" "Apps: App launcher" "exec-and-forget open -a Raycast")
  (skip "SUPER + P" "Windows: Pseudo-tile" "AeroSpace has no pseudo-tiling")
  (bind "SUPER + J" "Windows: Toggle split direction" "layout tiles horizontal vertical")
  (bind "SUPER + F" "Windows: Fullscreen" "fullscreen")
]
++ map (d: bind "SUPER + ${d}" "Focus: Focus ${d}" "focus ${d}") directions
++ [
  (bind "CTRL + ALT + SHIFT + h" "Focus: Focus left (vim)" "focus left")
  (bind "CTRL + ALT + SHIFT + j" "Focus: Focus down (vim)" "focus down")
  (bind "CTRL + ALT + SHIFT + k" "Focus: Focus up (vim)" "focus up")
  (bind "CTRL + ALT + SHIFT + l" "Focus: Focus right (vim)" "focus right")
]
++ map (d: bind "SUPER + SHIFT + ${d}" "Windows: Move window ${d}" "move ${d}") directions
++ map (n: bind "SUPER + ${n}" "Workspaces: Go to workspace ${n}" "workspace ${n}") workspaces
++ map (n: bind "SUPER + SHIFT + ${n}" "Workspaces: Move window to workspace ${n}" "move-node-to-workspace ${n}") workspaces
++ [
  (bind "SUPER + 0" "Workspaces: Toggle scratchpad" "workspace --auto-back-and-forth S")
  (bind "SUPER + SHIFT + 0" "Workspaces: Move window to workspace 10" "move-node-to-workspace 10")
  (bind "SUPER + S" "Workspaces: Toggle scratchpad" "workspace --auto-back-and-forth S")
  (bind "SUPER + SHIFT + S" "Workspaces: Move window to scratchpad" "move-node-to-workspace S")
  (bind "SUPER + ALT + S" "Workspaces: Toggle zone"
    (zone ''if [ "$ws" = "$n" ]; then aerospace workspace "''${n}z"; else aerospace workspace "$n"; fi''))
  (bind "SUPER + ALT + SHIFT + S" "Workspaces: Move window to zone"
    (zone ''aerospace move-node-to-workspace --focus-follows-window "''${n}z"''))
  (bind "SUPER + CTRL + ALT + S" "Workspaces: Move window to zone (silent)"
    (zone ''aerospace move-node-to-workspace "''${n}z"''))
  (bind "SUPER + SHIFT + minus" "Workspaces: Move workspace to previous monitor" "move-workspace-to-monitor --wrap-around prev")
  (bind "SUPER + SHIFT + equal" "Workspaces: Move workspace to next monitor" "move-workspace-to-monitor --wrap-around next")
  (skip "SUPER + mouse_down" "Workspaces: Next workspace (scroll)" "AeroSpace has no scroll bindings")
  (skip "SUPER + mouse_up" "Workspaces: Previous workspace (scroll)" "AeroSpace has no scroll bindings")
  (fnKey "Print" "Screenshots: Region screenshot + annotate" "F3" snip)
  (fnKey "SHIFT + Print" "Screenshots: Screen recording" "SHIFT + F3" "open -a Screenshot")
  (bind "SUPER + L" "System: Lock screen" "exec-and-forget pmset displaysleepnow")
  (bind "SUPER + M" "System: Power menu" "exec-and-forget osascript -e 'tell application \"loginwindow\" to «event aevtrsdn»'")
  (bind "SUPER + T" "System: Toggle light/dark theme" "exec-and-forget osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'")
  (skip "SUPER + N" "System: Notification center" "Notification Center has no command to open it")
  (bind "SUPER + slash" "Help: Welcome and keybinds" "exec-and-forget open -e ~/.config/keymap/cheatsheet.md")
  (skip "SUPER + SHIFT + slash" "Help: Search keybinds" "the cheatsheet is one page")
  (bind "SUPER + D" "System: Clear clipboard (drag-and-drop prep)" "exec-and-forget pbcopy < /dev/null")
  (skip "ALT + Tab" "Windows: Cycle floating windows" "AeroSpace cannot cycle floating windows")
  (skip "SHIFT + XF86AudioPlay" "System: Audio patchbay" "no patchbay on macOS")
  (skip "XF86AudioPlay" "Media: Play/pause" media)
  (skip "XF86AudioStop" "Media: Stop" media)
  (skip "XF86AudioMute" "Media: Mute" media)
  (skip "XF86AudioNext" "Media: Next track" media)
  (skip "XF86AudioPrev" "Media: Previous track" media)
  (skip "XF86AudioRaiseVolume" "Media: Volume up" media)
  (skip "XF86AudioLowerVolume" "Media: Volume down" media)
  (skip "XF86MonBrightnessUp" "Media: Brightness up" media)
  (skip "XF86MonBrightnessDown" "Media: Brightness down" media)
  (skip "SUPER + mouse:272" "Windows: Drag window (mouse)" "Ctrl+Cmd+drag moves a window (NSWindowShouldDragOnGesture)")
  (skip "SUPER + mouse:273" "Windows: Resize window (mouse)" "AeroSpace has no mouse resize")
  (macKey "F4" "Apps: App launcher (Spotlight key)" "open -a Raycast")
  (macKey "CMD + F1" "System: Keyboard backlight down" (backlight "-0.0625"))
  (macKey "CMD + F2" "System: Keyboard backlight up" (backlight "0.0625"))
  (stock "F5" "System: Dictation" "macOS dictation")
  (stock "F6" "System: Do Not Disturb" "macOS toggles Do Not Disturb")
]
