# Hyprland Theme Toggle

A comprehensive light/dark mode toggle system for Hyprland with Material You color generation.

## Features

- **Environment-based theme switching** - Safe for Electron apps like Cursor/VSCode
- **Material You colors** - Generated from wallpaper using matugen
- **HyprPanel integration** - Custom button with sun/moon icons
- **Multi-app support** - WezTerm, Wofi, Tmux, GTK apps
- **Crash-safe** - No runtime GTK changes that crash Electron apps

## Installation

1. Ensure dependencies are installed:
   ```bash
   # matugen for color generation
   # python3 for config generation
   # hyprpanel for UI integration
   ```

2. Set wallpaper path in `theme-toggle.sh`:
   ```bash
   WALLPAPER_PATH="$HOME/Pictures/your-wallpaper.png"
   ```

3. Install HyprPanel module:
   ```bash
   cp hyprpanel-module.ts ~/.config/hyprpanel/modules/theme-toggle.ts
   ```

4. Add theme-toggle to HyprPanel layout in `~/.config/hyprpanel/config.json`

## Usage

### Via Script
```bash
./theme-toggle-modular.sh
```

### Via Keybind
Add to Hyprland config:
```
bind = SUPER, T, exec, ~/scripts/hyprland-theme-toggle/theme-toggle-modular.sh
```

### Via HyprPanel
Click the sun/moon button in the panel

## How It Works

1. **Modular Architecture** - Each application has its own theme module
2. **Parallel Execution** - All modules run simultaneously for maximum speed
3. **Performance Monitoring** - Tracks execution time and alerts on slow modules (>0.25s)
4. **App Detection** - Only generates themes for installed applications
5. **Smart Caching** - Skips theme generation if configs are already up-to-date
6. **Environment Variables** - Uses `GTK_THEME` environment variable for new app launches
7. **D-Bus Integration** - Updates systemd user environment and D-Bus activation environment  
8. **Direct Color Access** - Gets Material You colors directly from matugen JSON output

## Files

- `theme-toggle-modular.sh` - Main theme switching script
- `modules/` - Application-specific theme modules:
  - `base.sh` - Shared module functions
  - `gtk.sh` - GTK environment variable management
  - `hyprpanel.sh` - HyprPanel restart logic
  - `wezterm.sh` - WezTerm configuration generation
  - `wofi.sh` - Wofi CSS generation
  - `tmux.sh` - Tmux theme configuration
  - `claude.sh` - Claude Code theme switching
- `hyprpanel-module.ts` - HyprPanel UI module
- `install.sh` - Installation script

## Module System

Each app module provides:
- **App detection** - Checks if application is installed
- **Performance monitoring** - Tracks execution time with 0.25s threshold
- **Theme caching** - Avoids regeneration if theme is current
- **Color integration** - Gets colors directly from matugen
- **Config generation** - Creates app-specific theme files

## Performance

The system runs all modules in parallel for optimal speed:

- ✅ **Fast modules** (under 0.25s): GTK, WezTerm, Wofi
- ⚠️ **Slower modules** (over 0.25s): Tmux, Claude Code, HyprPanel

Performance warnings help identify bottlenecks and optimization opportunities.

## Troubleshooting

### Electron Apps Not Theming
Electron apps need to be restarted to pick up new environment variables. This is by design to prevent crashes.

### Theme Not Persisting
Environment variables are set via systemd user environment and should persist across sessions.

### Colors Not Updating
Check that matugen is installed and wallpaper path is correct in the script.