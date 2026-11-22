# Hyprland configuration

The desktop environment lives in
[hypr-DE](https://github.com/MasonRhodesDev/hypr-DE). Compositor config,
waybar, swaync, fuzzel, theming templates, idle and lock policy, and the DE
scripts and units ship in the `hypr-de` package, which the `window-manager`
solution installs.

What the flake writes on top of it:

| Path | Solution | What it is |
|------|----------|------------|
| `~/.config/hypr/local.lua` | `window-manager`, assembled from the `hypr/*` fragments other solutions add | Per-machine overrides: autostart apps, window rules, binds. It runs after the packaged config, so it wins. |
| `~/.config/hypr/power.conf` | `window-manager` | hyprstate power policy. hyprstate reads only the user path. |
| `~/.config/uwsm/env` | `window-manager` | Session environment, such as the SSH agent socket. |
| `~/.config/hypr-de/xwayland-primary` | `window-manager` | The XWayland primary monitor, from `machine.private.xwaylandPrimary`. |
| `~/.config/hypr-de/hypridle.conf` | `suspend` | The idle timeouts knob file hypr-DE reads. |
| `~/.config/hypr-de/notify-plugins/` | `slack` | Per-app notification recovery plugins. |
| `~/.config/hypr/bp-*.lua`, `~/.config/hypr/scripts/bp-game-focus.py` | `steam-big-picture` | Steam Big Picture monitor and focus handling. |

Monitor profiles belong to hyprstate, which renders them at runtime. The flake
does not write them.

For the rest of the customization surface (lmtt module shadowing, systemd
drop-ins, `hypr-de-set-wallpaper`) see the hypr-DE README.
