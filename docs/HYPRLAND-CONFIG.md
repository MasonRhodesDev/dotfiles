# Hyprland Configuration Documentation

Complete guide to the Hyprland Wayland compositor configuration, keybindings, and desktop environment integration on Fedora and Arch Linux.

## Overview

This Hyprland setup provides:
- **Modern Wayland desktop** - Hardware-accelerated compositing
- **Intuitive keybindings** - Vim-inspired and productivity-focused
- **Multi-monitor support** - Dynamic display configuration
- **Window management** - Tiling and floating window control
- **Desktop integration** - Waybar, notifications, launchers

## Configuration Structure

```
~/.config/hypr/
├── hyprland.conf           # Main configuration file
├── hyprlock.conf          # Screen lock configuration
├── configs/               # Modular config files
│   ├── binds.conf         # Keybindings
│   ├── env.conf           # Environment variables
│   ├── exec.conf          # Startup applications
│   ├── monitors.conf      # Display configuration
│   └── rules.conf         # Window rules
└── scripts/               # Utility scripts
    ├── idle.sh            # Idle management
    ├── screen_off.sh      # Display power management
    └── monitors.sh        # Dynamic monitor setup
```

## Key Bindings

### Primary Modifier
- **Super (Windows key)** - Main modifier for window management
- **Alt** - Secondary modifier for application shortcuts
- **Ctrl+Alt** - System-level shortcuts

### Window Management

| Keybinding | Action |
|------------|--------|
| `Super + Q` | Close active window |
| `Super + V` | Toggle floating/tiling |
| `Super + F` | Toggle fullscreen |
| `Super + P` | Toggle pseudo-tiling |

### Navigation

| Keybinding | Action |
|------------|--------|
| `Super + H/J/K/L` | Move focus left/down/up/right |
| `Super + Shift + H/J/K/L` | Move window left/down/up/right |
| `Super + Ctrl + H/L` | Resize window horizontally |
| `Super + Ctrl + J/K` | Resize window vertically |

### Workspaces

| Keybinding | Action |
|------------|--------|
| `Super + 1-9` | Switch to workspace 1-9 |
| `Super + 0` | Switch to workspace 10 |
| `Super + Shift + 1-9` | Move window to workspace 1-9 |
| `Super + Mouse_Wheel` | Cycle through workspaces |

### Applications

| Keybinding | Action |
|------------|--------|
| `Super + Return` | Terminal (wezterm) |
| `Super + E` | File manager (nautilus) |
| `Super + R` | Application launcher (wofi) |
| `Super + Period` | Emoji picker (wofi) |
| `Alt + Tab` | Window switcher |

### System Control

| Keybinding | Action |
|------------|--------|
| `Super + L` | Lock screen (hyprlock) |
| `Super + Shift + E` | Logout menu |
| `Print` | Screenshot (full screen) |
| `Super + Print` | Screenshot (selection) |
| `Super + Shift + Print` | Screenshot (window) |

### Audio & Media

| Keybinding | Action |
|------------|--------|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |

## Monitor Configuration

### Dynamic Setup

The system automatically detects and configures monitors:

```bash
# ~/.config/hypr/configs/monitors.conf
monitor = , preferred, auto, 1

# Example multi-monitor setup
monitor = DP-3, 2560x1440@144, 0x0, 1
monitor = HDMI-A-1, 1920x1080@60, 2560x0, 1
```

### Monitor Scripts

**`monitors.sh`** - Dynamic monitor detection:
```bash
#!/bin/bash
# Automatically configure connected monitors
for monitor in $(hyprctl monitors | grep "Monitor" | awk '{print $2}'); do
    hyprctl keyword monitor "$monitor,preferred,auto,1"
done
```

### Wallpaper Management

Using hyprpaper for wallpaper display:
```bash
# Set wallpaper
hyprctl hyprpaper wallpaper "DP-3,/path/to/wallpaper.jpg"

# Preload wallpaper
hyprctl hyprpaper preload "/path/to/wallpaper.jpg"
```

## Window Rules

### Application-Specific Rules

```bash
# ~/.config/hypr/configs/rules.conf

# Floating windows
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$
windowrule = float, ^(file-roller)$

# Workspace assignments
windowrule = workspace 2, ^(firefox)$
windowrule = workspace 3, ^(code)$
windowrule = workspace 9, ^(discord)$

# Opacity rules
windowrule = opacity 0.9, ^(wezterm)$
windowrule = opacity 0.8, ^(thunar)$

# Size constraints
windowrule = size 800 600, ^(pavucontrol)$
windowrule = center, ^(pavucontrol)$
```

### Layer Rules

```bash
# Layerrules for special windows
layerrule = blur, waybar
layerrule = blur, wofi
layerrule = blur, swaync-control-center
layerrule = ignorezero, swaync-control-center
```

## Startup Applications

### Essential Services

```bash
# ~/.config/hypr/configs/exec.conf

# Authentication agent
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Desktop portal
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# Background services
exec-once = waybar
exec-once = swaync
exec-once = swayosd-server
exec-once = hyprpaper

# Theme management
exec-once = ~/.local/share/chezmoi/scripts/hyprland-theme-toggle/theme-restore.sh

# Idle management
exec-once = hypridle
```

## Environment Variables

### Wayland Configuration

```bash
# ~/.config/hypr/configs/env.conf

# Toolkit backends
env = GDK_BACKEND,wayland,x11
env = QT_QPA_PLATFORM,wayland;xcb
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland

# XDG desktop portal
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland

# GPU acceleration
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia

# Cursor theme
env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Adwaita
```

## Input Configuration

### Keyboard Settings

```bash
input {
    kb_layout = us
    kb_variant = 
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    natural_scroll = false
    numlock_by_default = true

    touchpad {
        natural_scroll = true
        tap-to-click = true
        drag_lock = true
        disable_while_typing = true
    }
}
```

### Mouse and Touchpad

```bash
device:epic-mouse-v1 {
    sensitivity = -0.5
}

device:touchpad {
    sensitivity = 0.1
    natural_scroll = true
}
```

## Appearance Settings

### Window Decoration

```bash
decoration {
    # Rounded corners
    rounding = 12
    
    # Borders
    border_size = 2
    col.active_border = rgba(6750a4ee) rgba(e9ddffee) 45deg
    col.inactive_border = rgba(625b7166)
    
    # Shadow
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}
```

### Blur Effects

```bash
decoration {
    # Background blur
    blur {
        enabled = true
        size = 3
        passes = 1
        new_optimizations = true
    }
}
```

### Animations

```bash
animations {
    enabled = true
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}
```

## Advanced Features

### Gestures

```bash
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_invert = true
    workspace_swipe_min_speed_to_force = 30
    workspace_swipe_cancel_ratio = 0.5
}
```

### Miscellaneous Settings

```bash
misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    enable_swallow = true
    swallow_regex = ^(wezterm)$
}
```

## Screen Lock (Hyprlock)

### Configuration

```bash
# ~/.config/hypr/hyprlock.conf

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 8
}

input-field {
    monitor =
    size = 200, 50
    position = 0, -80
    dots_center = true
    fade_on_empty = false
    placeholder_text = <i>Password...</i>
    hide_input = false
}

label {
    monitor =
    text = Hi there, $USER
    position = 0, 80
    font_size = 25
    font_family = JetBrains Mono
}
```

### Idle Management

```bash
# ~/.config/hypr/idle.sh
#!/bin/bash

# Lock after 5 minutes
timeout 300 'hyprlock' \
# Turn off displays after 10 minutes  
timeout 600 'hyprctl dispatch dpms off' \
# Turn on displays on resume
resume 'hyprctl dispatch dpms on' \
# Suspend after 30 minutes
timeout 1800 'systemctl suspend'
```

## Integration with Desktop Environment

### Waybar Integration

Hyprland provides workspace and window information to waybar:
```json
{
    "hyprland/workspaces": {
        "active-only": false,
        "all-outputs": true,
        "format": "{icon}",
        "format-icons": {
            "1": "󰈹",
            "2": "",
            "3": "󰨞",
            "urgent": "",
            "default": ""
        }
    }
}
```

### Notification Integration

SwayNC integrates with Hyprland for notifications:
```bash
# Show notification center
binds = Super, N, exec, swaync-client -t -sw

# Dismiss notifications
binds = Super+Shift, N, exec, swaync-client -d -sw
```

### Application Launcher

Wofi integration for application launching:
```bash
# Application launcher
binds = Super, R, exec, wofi --show drun

# Emoji picker
binds = Super, Period, exec, wofi --show emoji
```

## Troubleshooting

### Common Issues

**Windows not responding to keybindings:**
```bash
# Check if Hyprland is running
ps aux | grep hyprland

# Restart Hyprland
hyprctl reload
```

**Monitor configuration not applying:**
```bash
# List connected monitors
hyprctl monitors

# Manually set monitor
hyprctl keyword monitor "DP-3,1920x1080@60,0x0,1"

# Check monitor script
~/.config/hypr/configs/monitors.sh
```

**Applications not starting:**
```bash
# Check startup applications
hyprctl clients

# Manually start applications
waybar &
swaync &
```

### Performance Optimization

**For lower-end hardware:**
```bash
decoration {
    # Disable blur
    blur = false
    
    # Reduce shadow
    drop_shadow = false
}

animations {
    # Disable animations
    enabled = false
}
```

**For high refresh rate monitors:**
```bash
# Set refresh rate explicitly
monitor = DP-3, 2560x1440@144, 0x0, 1

# Optimize rendering
render {
    explicit_sync = 1
}
```

### Debugging

**Enable debug logging:**
```bash
# Run Hyprland with debug output
HYPRLAND_LOG_WLR=1 hyprland
```

**Check configuration errors:**
```bash
# Validate configuration
hyprctl reload

# Check logs
journalctl -u hyprland --since today
```

### Configuration Validation

```bash
# Test configuration changes
hyprctl reload

# Backup working configuration
cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.backup

# Restore if needed
cp ~/.config/hypr/hyprland.conf.backup ~/.config/hypr/hyprland.conf
```

## Tips and Best Practices

### Workflow Optimization

1. **Use workspaces effectively** - Assign applications to specific workspaces
2. **Master keybindings** - Learn the most common shortcuts
3. **Customize for your workflow** - Adjust window rules and bindings
4. **Use floating windows** - For dialog boxes and utilities

### Configuration Management

1. **Keep modular configs** - Separate bindings, rules, and settings
2. **Comment your changes** - Document custom configurations
3. **Test before committing** - Validate changes with `hyprctl reload`
4. **Backup working configs** - Save known-good configurations

### Resource Management

1. **Monitor resource usage** - Use `htop` to check performance
2. **Optimize for your hardware** - Adjust animations and effects
3. **Clean up startup applications** - Remove unnecessary exec-once entries
4. **Use appropriate window rules** - Prevent resource-heavy applications from hogging resources

---

This Hyprland configuration provides a modern, efficient, and customizable Wayland desktop environment with excellent hardware acceleration and window management capabilities.