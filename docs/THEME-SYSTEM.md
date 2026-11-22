# Theme System

Theming is handled by **[lmtt](https://github.com/MasonRhodesDev/linux-multi-theme-toggle)**
(Linux Multi-Theme Toggle), a standalone Rust tool.

## How it works

- **matugen** generates Material You colors from the wallpaper.
- **lmtt** injects the generated colors into application configs through
  per-app modules. hypr-DE ships the modules and templates for waybar,
  swaync, Neovim and the wallpaper. The `lmtt` solution in
  `nix/solutions/desktop/theming/lmtt` adds the kitty and hyprtoolkit modules,
  the GTK 3 and 4 CSS that imports the colors, and the tmux include.
- Generated files are prefixed `lmtt-*`. lmtt writes them at runtime, and the
  flake never manages them.
- `lmtt setup` injects the include hooks into app configs, and `lmtt cleanup`
  removes them.

## Usage

```bash
lmtt switch light|dark|toggle   # Switch or toggle theme
lmtt status                     # Show current theme
lmtt list                       # List installed modules
lmtt config                     # Interactive configuration
```

See the [lmtt repository](https://github.com/MasonRhodesDev/linux-multi-theme-toggle)
for module documentation.
