# Unified greetd Configuration

A redistributable, multi-distro greetd login manager with configurable features including optional JumpCloud authentication and game mode auto-login.

## Features

### Core Features (Always Included)
- **Modern GTK4 Greeter**: Clean Material Design interface via gtkgreet
- **GNOME Keyring Sync**: Automatically synchronizes keyring password with login password
- **PAM-based Authentication**: Secure, transparent password management
- **Multi-distro Support**: Fedora and Arch Linux
- **Configurable Desktop**: Choose your preferred window manager/desktop environment
- **Custom Wallpaper**: Use your own login background

### Optional Features (Configurable at Install Time)

#### JumpCloud Integration
- **Centralized Authentication**: Seamless integration with JumpCloud-managed accounts
- **Account Expiration**: Automatic enforcement of account policies
- **Enterprise Ready**: Perfect for fleet management and multi-machine deployments
- **Fallback Available**: Standard PAM authentication if JumpCloud not needed

#### Game Mode Auto-login
- **Automatic Detection**: Monitors gamepad input via custom service
- **Guide Button Activation**: Press gamepad guide button at login screen to enter game mode
- **Auto-login to Steam**: Boots directly into Steam Big Picture mode via gamescope
- **Seamless Switching**: Toggle between desktop and gaming modes on demand

## Requirements

### Base Requirements (All Configurations)
- **Supported OS**: Fedora Linux or Arch Linux
- **Packages**:
  - greetd (login manager)
  - gtkgreet / greetd-gtkgreet (GTK4 greeter interface)
  - gnome-keyring (password management)

### Optional Requirements

#### JumpCloud Authentication
- JumpCloud agent installed and configured
- `pam_jc_account_expiration.so` PAM module (provided by JumpCloud)

#### Game Mode
- gamescope (gaming compositor)
- steam (gaming platform)
- `/usr/local/bin/game-mode` binary (monitors gamepad input, not included)

## Installation

### Interactive Installation

The installer will prompt you to configure all options:

1. Clone or copy this directory to target machine
2. Run installer as root:
   ```bash
   sudo ./install.sh
   ```
3. Answer configuration prompts:
   - **JumpCloud integration**: Enable if you use JumpCloud for authentication
   - **Authentication methods**: Fingerprint, U2F tokens, Google Authenticator 2FA
   - **Desktop integration**: GNOME Keyring, KDE Wallet
   - **systemd-homed**: Enable if you use systemd-homed encrypted homes
   - **Game mode support**: Enable if you want gamepad auto-login to Steam
   - **Desktop environment**: Specify your WM/DE (Hyprland, sway, etc.)
   - **Auto-login user**: Choose which user for game mode (if enabled)
   - **Wallpaper**: Use custom wallpaper or bundled default
4. Review summary and confirm
5. **Set up authentication methods** (if enabled)
6. Reboot or restart display manager

### What the Installer Does

1. **Detects OS**: Identifies Fedora or Arch and configures appropriate package manager
2. **Validates packages**: Checks availability before attempting installation
3. **Installs dependencies**: Only installs packages needed for selected features
4. **Creates system user**: Sets up `greeter` user with minimal required permissions
5. **Backs up configs**: Preserves existing configurations with timestamps
6. **Deploys templates**: Generates configuration files with your chosen settings
7. **Configures PAM**: Installs appropriate authentication stack (with or without JumpCloud)
8. **Enables services**: Optionally installs game-mode monitoring service
9. **Switches display manager**: Offers to disable existing DM and enable greetd

## Configuration Modes

### Desktop Mode (Default)
- **Config**: `/etc/greetd/mode-desktop.toml`
- **Interface**: gtkgreet with Material Design theme
- **Login**: Manual password entry with keyring sync
- **Authentication**: JumpCloud (if enabled) or standard PAM
- **Use Case**: Standard desktop workstation usage

### Game Mode (Optional)
- **Config**: `/etc/greetd/mode-game.toml` (only created if game mode enabled)
- **Interface**: None (auto-login)
- **Login**: Automatic as configured user
- **Command**: `/usr/bin/gamescope -e -- /usr/bin/steam -gamepadui`
- **Use Case**: Console-style gaming experience
- **Note**: Only available if game mode was enabled during installation

## Mode Switching

**Note**: Mode switching is only available if game mode was enabled during installation.

### Automatic Switching (Recommended)
If the `game-mode.service` is installed and running, it monitors gamepad input and automatically switches modes:

1. At login screen, press gamepad guide button
2. Service detects button press
3. Config symlink updates: `mode-desktop.toml` → `mode-game.toml`
4. greetd restarts
5. System auto-logs in and launches Steam Big Picture

Returns to desktop mode when:
- User logs out from Steam
- Manual mode switch is triggered
- Service detects no active gaming session

### Manual Switching
Switch modes manually via command line:

**To Game Mode:**
```bash
sudo ln -sf /etc/greetd/mode-game.toml /etc/greetd/config.toml
sudo systemctl restart greetd
```

**To Desktop Mode:**
```bash
sudo ln -sf /etc/greetd/mode-desktop.toml /etc/greetd/config.toml
sudo systemctl restart greetd
```

## Authentication Methods

The installer supports multiple authentication methods that can be combined for flexible and secure login options.

### Base Authentication

#### Standard UNIX Authentication (Default)
- Authenticates against local `/etc/shadow` passwords
- Always available as fallback
- No additional setup required

#### JumpCloud Integration (Optional)
- Authenticates against JumpCloud cloud directory
- Enforces centralized account policies
- Requires JumpCloud agent installed
- **Setup**: Install and configure JumpCloud agent before enabling

### Alternative Authentication Methods

These methods are tried **before** password authentication, allowing convenient login while maintaining password fallback.

#### Fingerprint (pam_fprintd)
- **Requirements**: Fingerprint reader hardware, fprintd installed
- **Setup**: Run `/etc/greetd/scripts/setup-fingerprint` as your user
- **Enrollment**: Scan finger multiple times for accuracy
- **Fallback**: Password authentication if fingerprint fails
- **Security**: Biometric data stored locally, not shared

```bash
# After installation, enroll fingerprints
/etc/greetd/scripts/setup-fingerprint

# Enable fprintd service
sudo systemctl enable --now fprintd.service
```

#### U2F Hardware Tokens (pam_u2f)
- **Requirements**: U2F-compatible hardware key (YubiKey, etc.)
- **Setup**: Run `/etc/greetd/scripts/setup-u2f` as your user
- **Registration**: Register multiple tokens for backup
- **Fallback**: Password authentication if token not present
- **Security**: Phishing-resistant, hardware-backed authentication

```bash
# After installation, register U2F tokens
/etc/greetd/scripts/setup-u2f
```

### Two-Factor Authentication

#### Google Authenticator (pam_google_authenticator)
- **Requirements**: Smartphone with authenticator app (Google Authenticator, Authy, 1Password, etc.)
- **Setup**: Run `/etc/greetd/scripts/setup-google-auth` as your user
- **Flow**: Enter password **then** 6-digit code from app
- **Backup**: Emergency scratch codes generated during setup
- **Security**: Time-based one-time passwords (TOTP)

```bash
# After installation, set up 2FA
/etc/greetd/scripts/setup-google-auth

# Save emergency scratch codes displayed during setup!
```

**IMPORTANT**: With Google Authenticator enabled, you must provide BOTH password and 6-digit code to log in.

### Advanced Features

#### systemd-homed Support
- **Requirements**: Home directories managed by systemd-homed
- **Features**: Automatic home directory mounting/unmounting, encryption support
- **Setup**: Configure systemd-homed before enabling in greetd
- **Use Case**: Portable encrypted home directories, multi-host environments

### Desktop Integration

#### GNOME Keyring (Default)
- Automatically unlocks GNOME Keyring with login password
- Prevents "unlock keyring" prompts after login
- Works with all authentication methods
- Enabled by default, can be disabled during installation

#### KDE Wallet (Optional)
- Automatically unlocks KDE Wallet with login password
- Required for KDE Plasma users who use KWallet
- Can be enabled alongside GNOME Keyring
- **Note**: Must be configured after first login

### Authentication Flow Examples

**Standard password login**:
```
1. Enter username
2. Enter password
3. Login granted
```

**With fingerprint enabled**:
```
1. Enter username
2. Scan fingerprint → Success, login granted
   OR
2. Scan fails → Falls back to password entry
```

**With fingerprint + Google Auth**:
```
1. Enter username
2. Scan fingerprint → Success
3. Enter 6-digit code from app
4. Login granted
```

**With U2F + Google Auth**:
```
1. Enter username
2. Insert U2F key and touch → Success
3. Enter 6-digit code from app
4. Login granted
```

### Security Considerations

**Brute Force Protection (pam_faillock)**:
- Automatically enabled with all configurations
- Default: Account locked after 5 failed attempts
- Lockout duration: 15 minutes (configurable in PAM)
- Applies to all authentication methods

**Testing New Authentication Methods**:
1. Keep a root terminal open
2. Test login in separate TTY (Ctrl+Alt+F2)
3. Verify fallback to password works
4. Only log out of main session after confirming

**Recovery**:
- Password authentication always available as fallback
- Emergency scratch codes for Google Authenticator
- Boot to single-user mode to remove PAM configs if locked out

## File Structure

```
greetd_config_merged/
├── README.md                           # This file
├── install.sh                          # Interactive installation script
│
├── config/                             # Configuration files
│   ├── mode-desktop.toml              # Desktop mode greetd config template
│   ├── mode-game.toml                 # Game mode greetd config template
│   ├── gtkgreet.css                   # Greeter styling
│   ├── pam-greetd.standard            # PAM config (legacy, for reference)
│   ├── pam-greetd.with-jumpcloud      # PAM config (legacy, for reference)
│   ├── pam-snippets/                  # Modular PAM configuration snippets
│   │   ├── auth-base-preauth.conf     # Faillock + pam_env
│   │   ├── auth-unix.conf             # Standard UNIX password auth
│   │   ├── auth-jumpcloud.conf        # JumpCloud authentication
│   │   ├── auth-fingerprint.conf      # Fingerprint (fprintd)
│   │   ├── auth-u2f.conf              # U2F hardware tokens
│   │   ├── auth-google-authenticator.conf  # Google Authenticator 2FA
│   │   ├── auth-postauth.conf         # Faillock authfail + deny
│   │   ├── account-*.conf             # Account management modules
│   │   ├── password-*.conf            # Password change modules
│   │   ├── session-*.conf             # Session setup modules
│   │   └── keyring-*.conf             # Keyring/wallet unlock modules
│   └── environments                   # Wayland environment variables
│
├── scripts/                            # Helper scripts
│   ├── sync-keyring-password          # Keyring password sync utility
│   ├── game-mode-wrapper.sh           # Alternative Steam launcher
│   ├── setup-fingerprint              # Fingerprint enrollment wizard
│   ├── setup-u2f                      # U2F token registration wizard
│   └── setup-google-auth              # Google Authenticator setup wizard
│
├── systemd/                            # Systemd service files
│   └── game-mode.service              # Game mode detection service
│
├── themes/                             # Visual themes
│   └── regreet.css                    # Material Design CSS theme
│
└── assets/                             # Static assets
    └── wallpaper.png                  # Default login background
```

**Note**: The installer dynamically generates `/etc/pam.d/greetd` from snippets based on selected features.

## Deployed File Locations

After installation, files are deployed to:

```
/etc/greetd/
├── config.toml → mode-desktop.toml    # Active config (symlink)
├── mode-desktop.toml                  # Desktop mode config
├── mode-game.toml                     # Game mode config (if enabled)
├── gtkgreet.css                       # Greeter styling
├── environments                       # Environment variables
├── css/
│   └── regreet.css                    # Material Design theme
├── scripts/
│   ├── sync-keyring-password          # Keyring sync script
│   └── game-mode-wrapper.sh           # Steam launcher (if game mode enabled)
└── logs/
    └── game-mode.log                  # Game mode logs (if service running)

/etc/pam.d/
└── greetd                             # PAM config (standard OR with-jumpcloud)

/etc/systemd/system/
└── game-mode.service                  # Game mode service (if enabled + binary present)

/var/lib/greetd/
└── wallpaper.png                      # Login wallpaper

/usr/local/bin/
└── game-mode                          # Game mode binary (not included, optional)
```

**Configuration backups**: Existing configs are backed up to `filename.bak.YYYYMMDD-HHMMSS` before being overwritten.

## Password Synchronization

### How It Works

#### Standard PAM Authentication
1. User enters password at login screen
2. PAM authenticates via standard UNIX authentication
3. pam_gnome_keyring attempts to unlock keyring
4. If successful, keyring is unlocked with login password
5. Session starts with unlocked keyring

#### With JumpCloud (If Enabled)
1. User enters password at login screen
2. PAM authenticates via JumpCloud module
3. JumpCloud checks account expiration and policies
4. On success, pam_gnome_keyring attempts to unlock keyring
5. If successful, keyring is unlocked with login password
6. Session starts with unlocked keyring

### Requirements

- GNOME Keyring must be initialized for user
- Login password and keyring password should match for auto-unlock
- If using JumpCloud: JumpCloud agent must be running

### Troubleshooting Password Sync

**Keyring doesn't auto-unlock:**
- Check `/etc/pam.d/greetd` has pam_gnome_keyring entries
- Verify gnome-keyring is installed: `pacman -Q gnome-keyring` or `rpm -q gnome-keyring`
- Manually reset keyring: `rm -rf ~/.local/share/keyrings/`

**JumpCloud authentication fails (if enabled):**
- Ensure pam_jc_account_expiration.so is present: `ls /lib/security/pam_jc_account_expiration.so`
- Check JumpCloud agent is running: `systemctl status jcagent`
- Verify network connectivity to JumpCloud servers

## Game Mode Service

### Service Details

**Location**: `/etc/systemd/system/game-mode.service`
**Binary**: `/usr/local/bin/game-mode`
**User**: greeter (with input/video group access)
**Logs**: `/etc/greetd/logs/game-mode.log`

### Monitoring Service

Check service status:
```bash
systemctl status game-mode.service
```

View logs:
```bash
tail -f /etc/greetd/logs/game-mode.log
```

Restart service:
```bash
sudo systemctl restart game-mode.service
```

### Troubleshooting Game Mode

**Service won't start:**
- Check binary exists: `ls -l /usr/local/bin/game-mode`
- Verify greeter user groups: `groups greeter`
- Check logs for errors

**Gamepad not detected:**
- Verify gamepad is connected: `ls /dev/input/event*`
- Check permissions on input devices
- Test with `evtest` utility

**Mode doesn't switch:**
- Verify symlink creation permissions
- Check greetd service is running
- Review game-mode.log for errors

## Customization

### Change Auto-login User (Game Mode)
Edit `/etc/greetd/mode-game.toml`:
```toml
user = "your-username"
```

### Change Desktop Environment
Edit `/etc/greetd/mode-desktop.toml` initial_session section:
```toml
[initial_session]
command = "sway"  # or "Hyprland", "gnome-session", etc.
user = "your-username"
```

### Change Steam Launch Command (Game Mode)
Edit `/etc/greetd/mode-game.toml`:
```toml
# Options:
command = "/usr/bin/gamescope -e -- /usr/bin/steam -gamepadui"
# OR
command = "/etc/greetd/scripts/game-mode-wrapper.sh"
# OR
command = "steam -tenfoot"
```

### Change Wallpaper
Replace `/var/lib/greetd/wallpaper.png` with your image, or set `$WALLPAPER_PATH` before running installer

### Modify Theme
Edit `/etc/greetd/css/regreet.css` for appearance changes

### Add/Remove Features Post-Install
To add features after initial install, re-run `sudo ./install.sh` and select different options. The installer will back up existing configs.

## Security Considerations

### Auto-login Security
- Game mode uses auto-login for convenience
- This bypasses authentication - only use on trusted devices
- Consider physical security of device when enabling game mode
- Desktop mode always requires password authentication

### PAM Configuration
- PAM config includes SELinux support
- JumpCloud handles account expiration checks
- Keyring sync maintains encryption at rest
- Session keyring properly initialized

## Distribution & Deployment

This configuration is fully redistributable across Fedora and Arch Linux systems.

### Single Machine Deployment

1. Copy entire `greetd_config_merged` directory to target machine
2. (Optional) Place game-mode binary at `/usr/local/bin/game-mode` if using game mode
3. (Optional) Set `$WALLPAPER_PATH` environment variable for custom wallpaper
4. Run `sudo ./install.sh` and follow prompts
5. Reboot

### Fleet/Mass Deployment

For deploying to multiple machines:

**Option 1: Non-interactive with environment variables**
```bash
# Set configuration via environment variables
export WALLPAPER_PATH="/path/to/wallpaper.png"
# Then modify install.sh to support non-interactive mode (future enhancement)
```

**Option 2: Configuration management**
- Use Ansible/Salt/Puppet to:
  1. Copy files to target machines
  2. Pre-configure PAM based on host groups
  3. Deploy appropriate mode configs
  4. Enable services

**Option 3: System images**
- Run installer once on reference machine
- Capture `/etc/greetd/` and `/var/lib/greetd/` in image
- Ensure user accounts exist on target systems

**Option 4: Package as distribution package**
- Create RPM (Fedora) or PKGBUILD (Arch)
- Include post-install scripts to run configuration
- Handle dependencies via package manager

## Uninstallation

To remove this configuration:

1. Disable services:
   ```bash
   sudo systemctl disable greetd.service
   sudo systemctl disable game-mode.service
   ```

2. Remove files:
   ```bash
   sudo rm -rf /etc/greetd
   sudo rm /etc/pam.d/greetd
   sudo rm /etc/systemd/system/game-mode.service
   sudo rm -rf /var/lib/greetd
   ```

3. Re-enable previous display manager:
   ```bash
   sudo systemctl enable gdm.service  # or your DM
   ```

4. Reboot

## Credits

This configuration provides:
- Multi-distro greetd setup tool (Fedora, Arch)
- Flexible authentication: password, fingerprint, U2F, 2FA
- Optional JumpCloud authentication integration
- Optional game mode with gamepad detection
- GNOME Keyring and KDE Wallet integration
- systemd-homed support
- Material Design themed GTK4 greeter
- Brute-force protection with pam_faillock

## Changelog

### v2.1 - PAM Authentication Suite
- **CRITICAL FIX**: Added pam_systemd (required for systemd user services)
- **CRITICAL FIX**: Added pam_faillock brute-force protection
- Added fingerprint authentication support (pam_fprintd)
- Added U2F hardware token support (pam_u2f)
- Added Google Authenticator 2FA (pam_google_authenticator)
- Added KDE Wallet auto-unlock (pam_kwallet5)
- Added systemd-homed support (pam_systemd_home)
- Implemented modular PAM snippet architecture
- Dynamic PAM config generation based on selected features
- Added setup wizard scripts for fingerprint, U2F, and Google Auth
- Updated package management for optional PAM modules
- Comprehensive authentication methods documentation

### v2.0 - Multi-distro Refactor
- Added Fedora and Arch Linux support
- Made JumpCloud integration optional
- Made game mode optional
- Added interactive installer with feature selection
- Added config backup mechanism
- Added dependency validation
- Removed hardcoded usernames and paths

### v1.0 - Initial Merge
- Merged password sync and game mode features
- Fedora-only support
- Required JumpCloud and game mode

## License

Freely redistributable for personal and commercial use.
