# Hyprland configuration

The desktop environment moved out of this repo into
[hypr-DE](https://github.com/MasonRhodesDev/hypr-DE) (2026-08). Compositor
config, waybar, swaync, fuzzel, theming templates, idle/lock policy, and all
DE scripts/units ship in the `hypr-de` package.

What this repo still owns:

- `~/.config/hypr/local.lua` — per-machine overrides (autostart apps, personal
  window rules, gaming opt-in); runs after the packaged config, last-wins
- `~/.config/hypr/profiles/` — monitor layouts (hyprstate selects by EDID)
- `~/.config/hypr/power.conf` — hyprstate power policy (hyprstate reads the
  user path only)
- `~/.config/hypr-de/notify-plugins/` — per-app notification recovery plugins
- `~/.config/uwsm/env` — personal session env (SSH agent socket)

Everything else: see the hypr-DE README for the customization surface
(lmtt module shadowing, systemd drop-ins, `hypr-de-set-wallpaper`).
