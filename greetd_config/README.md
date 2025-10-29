# greetd Configuration

Modern greetd setup with ReGreet (GTK4) greeter, Material Design theme, and automatic keyring password synchronization for JumpCloud-managed accounts.

## Features

- **gtkgreet GTK4 greeter** with Material Design styling
- **Automatic keyring password sync** via PAM integration
- **Wallpaper integration** from `$WALLPAPER_PATH`
- **JumpCloud compatibility** for cloud-managed credentials

## Installation

```bash
./install.sh
```

## Structure

- `config/` - greetd and ReGreet configuration files
- `scripts/` - Helper scripts for keyring sync and session management
- `themes/` - Material Design CSS for ReGreet
- `assets/` - Wallpapers and graphics
- `install.sh` - Automated installer

## Requirements

- greetd
- gtkgreet (GTK4 greeter)
- gnome-keyring
- JumpCloud agent (for password sync)
