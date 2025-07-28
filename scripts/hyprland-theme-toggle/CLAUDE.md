# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Primary Scripts
- `./theme-toggle-modular.sh` - Main theme switching script
- `./install.sh` - Installation script that makes scripts executable and sets up HyprPanel integration
- `./generate-theme-configs.py <wallpaper_path> <mode>` - Python utility for generating Wofi CSS and WezTerm configs

### Testing & Development
- No automated tests - this is a shell script-based system
- Test by running `./theme-toggle-modular.sh` and verifying theme changes across applications
- Check logs in terminal output for module performance warnings and errors

## Architecture

### Modular Theme System
The codebase uses a modular architecture centered around `theme-toggle-modular.sh` that orchestrates theme switching across multiple applications:

1. **Core Components**:
   - `modules/base.sh` - Shared functions for app detection, performance monitoring, theme caching, and logging
   - `theme-toggle-modular.sh` - Main orchestrator that runs modules in parallel
   - `modules/*.sh` - Application-specific theme modules (gtk, wezterm, wofi, tmux, claude, hyprpanel)

2. **Module System**:
   - Each module implements `{module_name}_apply_theme()` function
   - Modules check app installation, theme caching, and apply themes independently
   - Performance monitoring tracks execution time with 0.25s threshold warnings
   - All modules run in parallel for optimal speed

3. **Color Generation**:
   - Uses `matugen` to generate Material You colors from wallpaper
   - Colors are pulled directly from matugen JSON output
   - Python script `generate-theme-configs.py` handles complex config generation for Wofi/WezTerm

4. **State Management**:
   - Theme state stored in `~/.cache/theme_state`
   - Environment variables set via systemd user environment and D-Bus
   - Uses `GTK_THEME` environment variable for crash-safe Electron app theming

### Key Design Principles
- **Crash Safety**: Uses environment variables instead of runtime GTK changes to prevent Electron app crashes
- **Performance**: Parallel module execution with performance monitoring and warnings
- **Smart Caching**: Skips theme generation if configs are newer than wallpaper/state files
- **App Detection**: Only applies themes to installed applications

### Integration Points
- **HyprPanel**: TypeScript module at `hyprpanel-module.ts` provides UI button
- **Hyprland**: Can be bound to keybinds via Hyprland config
- **Wallpaper**: Configurable wallpaper path in main script (default: `~/Pictures/forrest.png`)

## Module Development
When adding new application support:
1. Create new module in `modules/{app}.sh`
2. Implement `{app}_apply_theme()` function
3. Use base.sh functions: `app_installed()`, `theme_cached()`, `log_module()`
4. Source base.sh and follow existing module patterns
5. Test performance to stay under 0.25s threshold when possible