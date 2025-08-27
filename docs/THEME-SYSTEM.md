# Theme System Documentation

The theme system provides automatic Material You color generation from wallpapers and applies consistent theming across all desktop applications.

## Overview

The modular theme system consists of:
- **matugen** - Generates Material You colors from images
- **Template files** - Dynamic configs using generated colors
- **Theme modules** - Application-specific theme applicators
- **Toggle scripts** - User interfaces for theme switching

## Architecture

```
scripts/hyprland-theme-toggle/
├── executable_theme-toggle-modular.sh  # Main toggle script
├── theme-restore.sh                    # Restore saved theme
├── generate-theme-configs.py           # Template processor
└── modules/                            # Application modules
    ├── base.sh                         # Core theme functions
    ├── gtk.sh                          # GTK 3/4 applications
    ├── hyprpanel.sh                    # System panel
    ├── nvim.sh                         # Neovim editor
    ├── qt.sh                           # Qt applications
    ├── swaync.sh                       # Notifications
    ├── tmux.sh                         # Terminal multiplexer
    ├── waybar.sh                       # Status bar
    ├── wezterm.sh                      # Terminal
    ├── wofi.sh                         # Application launcher
    └── xdg.sh                          # Desktop environment
```

## Color Generation

### matugen Integration

The system uses [matugen](https://github.com/InioX/matugen) to generate Material You color palettes:

```bash
# Generate from wallpaper
matugen image /path/to/wallpaper.jpg

# Generate with custom settings
matugen image /path/to/wallpaper.jpg --mode dark --format hex
```

### Template Files

Colors are applied via chezmoi templates in `~/.config/matugen/templates/`:

- `colors.css` - CSS custom properties for web-based apps
- `waybar.css` - Waybar status bar styling
- `wezterm.lua` - Terminal color scheme
- `wofi.css` - Application launcher styling

## Theme Modules

### Base Module (`base.sh`)

Provides core functionality used by all modules:

```bash
#!/usr/bin/env bash
source ~/scripts/hyprland-theme-toggle/modules/base.sh

# Available functions:
apply_theme_to_app "appname"
reload_app "appname"
log_theme_action "message"
```

### Application Modules

Each module handles theme application for specific applications:

#### GTK Module (`gtk.sh`)
- Updates `~/.config/gtk-3.0/settings.ini`
- Updates `~/.config/gtk-4.0/settings.ini`
- Sets GTK theme to Adwaita-dark/Adwaita
- Reloads GTK applications

#### Waybar Module (`waybar.sh`)
- Applies CSS from matugen template
- Reloads waybar with new styling
- Updates icon colors and backgrounds

#### Neovim Module (`nvim.sh`)
- Generates colorscheme from theme colors
- Updates background transparency
- Reloads active Neovim instances

#### Terminal Module (`wezterm.sh`)
- Applies color scheme from template
- Updates background opacity
- Live reloads terminal sessions

## Usage

### Basic Theme Toggle

```bash
# Toggle to dark theme
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh dark

# Toggle to light theme
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh light

# Auto-detect from wallpaper
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh
```

### Advanced Usage

```bash
# Set wallpaper and apply theme
hyprctl hyprpaper wallpaper "DP-3,/path/to/wallpaper.jpg"
~/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh

# Apply only specific modules
~/scripts/hyprland-theme-toggle/modules/gtk.sh
~/scripts/hyprland-theme-toggle/modules/waybar.sh

# Restore previously saved theme
~/scripts/hyprland-theme-toggle/theme-restore.sh
```

## Adding New Applications

### Creating a New Module

1. Create module file:
```bash
#!/usr/bin/env bash
# Module for MyApp theme integration

source "$(dirname "$0")/base.sh"

apply_myapp_theme() {
    log_theme_action "Applying theme to MyApp"
    
    # Read colors from matugen
    local bg_color=$(jq -r '.colors.primary' ~/.config/matugen/colors.json)
    local fg_color=$(jq -r '.colors.on_primary' ~/.config/matugen/colors.json)
    
    # Apply to config
    sed -i "s/background=.*/background=$bg_color/" ~/.config/myapp/config
    sed -i "s/foreground=.*/foreground=$fg_color/" ~/.config/myapp/config
    
    # Reload application
    pkill -USR1 myapp 2>/dev/null || true
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    apply_myapp_theme
fi
```

2. Make executable:
```bash
chmod +x ~/scripts/hyprland-theme-toggle/modules/myapp.sh
```

3. Add to main toggle script:
```bash
# Edit executable_theme-toggle-modular.sh
# Add to module list:
modules=(
    "base"
    "gtk" 
    "qt"
    "waybar"
    "wezterm"
    "nvim"
    "myapp"  # <- Add here
)
```

### Template Integration

For complex theming, create a matugen template:

1. Create template file:
```bash
# ~/.config/matugen/templates/myapp.conf
background = {{colors.primary}}
foreground = {{colors.on_primary}}
accent = {{colors.secondary}}
```

2. Reference in module:
```bash
apply_myapp_theme() {
    # Template is auto-processed by matugen
    cp ~/.config/matugen/myapp.conf ~/.config/myapp/theme.conf
    reload_app "myapp"
}
```

## Color Variables

### Available Colors

matugen provides extensive color palettes:

```json
{
  "colors": {
    "primary": "#6750a4",
    "on_primary": "#ffffff", 
    "primary_container": "#e9ddff",
    "on_primary_container": "#22005d",
    "secondary": "#625b71",
    "on_secondary": "#ffffff",
    "surface": "#fef7ff",
    "on_surface": "#1d1b20",
    "background": "#fef7ff",
    "on_background": "#1d1b20"
  }
}
```

### Custom Properties

Define custom colors for specific needs:

```css
:root {
  --theme-bg: {{colors.background}};
  --theme-fg: {{colors.on_background}};
  --theme-accent: {{colors.primary}};
  --theme-surface: {{colors.surface}};
  
  /* Custom derived colors */
  --theme-bg-alt: color-mix(in srgb, {{colors.background}} 90%, {{colors.surface}});
  --theme-border: color-mix(in srgb, {{colors.on_background}} 20%, transparent);
}
```

## Troubleshooting

### Theme Not Applying

1. **Check matugen installation:**
```bash
command -v matugen || echo "matugen not found"
```

2. **Verify color generation:**
```bash
ls ~/.config/matugen/
cat ~/.config/matugen/colors.json
```

3. **Test individual modules:**
```bash
~/scripts/hyprland-theme-toggle/modules/gtk.sh
~/scripts/hyprland-theme-toggle/modules/waybar.sh
```

### Application Not Updating

1. **Manual reload:**
```bash
# GTK apps
killall -USR1 nautilus

# Waybar
killall waybar && waybar &

# Neovim
echo 'colorscheme theme' | nvim --server ~/.cache/nvim/server.pipe --remote-send
```

2. **Check configuration files:**
```bash
# Verify theme files were updated
ls -la ~/.config/gtk-3.0/settings.ini
cat ~/.config/waybar/style.css | head -10
```

### Performance Issues

For systems with limited resources:

1. **Disable heavy modules:**
```bash
# Edit toggle script, comment out resource-intensive modules
# modules=(
#     "base"
#     "gtk"
#     # "qt"      # Disable Qt theming
#     "waybar"
# )
```

2. **Cache theme states:**
```bash
# Save current theme for faster switching
cp ~/.config/matugen/colors.json ~/.config/matugen/theme-cache.json
```

## Configuration Files

### Key Files Modified by Theme System

| Application | Config File | Template Source |
|-------------|-------------|-----------------|
| GTK 3 | `~/.config/gtk-3.0/settings.ini` | Generated |
| GTK 4 | `~/.config/gtk-4.0/settings.ini` | Generated |
| Waybar | `~/.config/waybar/style.css` | `matugen/templates/waybar.css` |
| Wezterm | `~/.wezterm.lua` | `matugen/templates/wezterm.lua` |
| Wofi | `~/.config/wofi/style.css` | `matugen/templates/wofi.css` |
| SwayNC | `~/.config/swaync/style.css` | Generated |
| Neovim | `~/.config/nvim/colors/theme.vim` | Generated |

### Backup and Restore

The system automatically backs up original configs:

```bash
# Backup location
~/.config/matugen/backups/

# Restore original configs
cp ~/.config/matugen/backups/gtk-3.0-settings.ini ~/.config/gtk-3.0/settings.ini
```

---

This modular approach ensures consistent theming while maintaining flexibility for individual application preferences.