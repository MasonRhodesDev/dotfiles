# Theme System

Theming is handled by **[lmtt](https://github.com/MasonRhodesDev/linux-multi-theme-toggle)**
(Linux Multi-Theme Toggle), a standalone Rust tool — the old
`scripts/hyprland-theme-toggle/` module system documented here previously
was removed.

## How it works

- **matugen** generates Material You colors from the wallpaper
  (templates in `dot_config/matugen/`).
- **lmtt** injects the generated colors into application configs via
  per-app modules. Generated files are prefixed `lmtt-*` and are excluded
  from chezmoi by `.chezmoiignore` (`**/lmtt-*`).
- `lmtt setup` injects the include hooks into app configs; `lmtt cleanup`
  removes them. The mako config is fully generated from
  `dot_config/lmtt/modules/mako.toml`, so `~/.config/mako/config` is also
  chezmoi-ignored.

## Usage

```bash
lmtt switch light|dark|toggle   # Switch or toggle theme
lmtt status                     # Show current theme
lmtt list                       # List installed modules
lmtt config                     # Interactive configuration
```

See the [lmtt repository](https://github.com/MasonRhodesDev/linux-multi-theme-toggle)
for module documentation.
