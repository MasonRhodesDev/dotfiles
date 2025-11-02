#!/bin/bash
# Unified greetd installation script with password sync and optional game mode
# Supports Fedora and Arch Linux
# Requires root privileges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPTIONS_FILE="/etc/greetd/install-options.conf"
UPDATE_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--update)
            UPDATE_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: sudo ./install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -u, --update    Update mode: use previously saved installation options"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() { echo -e "${RED}ERROR: $1${NC}" >&2; }
success() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}WARNING: $1${NC}"; }
info() { echo "$1"; }

# Save installation options to file
save_options() {
    cat > "$OPTIONS_FILE" <<EOF
# greetd installer options - saved $(date)
ENABLE_JUMPCLOUD=$ENABLE_JUMPCLOUD
ENABLE_FINGERPRINT=$ENABLE_FINGERPRINT
ENABLE_U2F=$ENABLE_U2F
ENABLE_GOOGLE_AUTH=$ENABLE_GOOGLE_AUTH
ENABLE_SYSTEMD_HOME=$ENABLE_SYSTEMD_HOME
ENABLE_GNOME_KEYRING=$ENABLE_GNOME_KEYRING
ENABLE_KDE_WALLET=$ENABLE_KDE_WALLET
ENABLE_GAME_MODE=$ENABLE_GAME_MODE
DESKTOP_ENV="$DESKTOP_ENV"
AUTOLOGIN_USER="$AUTOLOGIN_USER"
EOF
    chmod 644 "$OPTIONS_FILE"
    info "Installation options saved to $OPTIONS_FILE"
}

# Load installation options from file
load_options() {
    if [ ! -f "$OPTIONS_FILE" ]; then
        error "No saved options found at $OPTIONS_FILE"
        echo "Run installer without --update flag for first-time installation"
        exit 1
    fi

    source "$OPTIONS_FILE"
    success "Loaded saved options from $OPTIONS_FILE"
    info "Using previous configuration:"
    info "  - JumpCloud: $ENABLE_JUMPCLOUD"
    info "  - Fingerprint: $ENABLE_FINGERPRINT"
    info "  - U2F: $ENABLE_U2F"
    info "  - Google Auth: $ENABLE_GOOGLE_AUTH"
    info "  - systemd-homed: $ENABLE_SYSTEMD_HOME"
    info "  - GNOME Keyring: $ENABLE_GNOME_KEYRING"
    info "  - KDE Wallet: $ENABLE_KDE_WALLET"
    info "  - Game mode: $ENABLE_GAME_MODE"
    info "  - Desktop: $DESKTOP_ENV"
    [ "$ENABLE_GAME_MODE" = true ] && info "  - Auto-login user: $AUTOLOGIN_USER"
    echo
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Detect the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

echo "==> greetd Unified Installer"
echo "    Multi-distro support: Fedora, Arch"
echo "    Features: Configurable authentication + optional game mode"
echo

# ============================================================================
# OS DETECTION
# ============================================================================

info "[1/14] Detecting operating system..."

if [ ! -f /etc/os-release ]; then
    error "Cannot detect OS - /etc/os-release not found"
    exit 1
fi

source /etc/os-release

DISTRO=""
PKG_MANAGER=""
PKG_INSTALL_CMD=""

case "$ID" in
    fedora)
        DISTRO="fedora"
        PKG_MANAGER="dnf"
        PKG_INSTALL_CMD="dnf install -y"
        ;;
    arch)
        DISTRO="arch"
        PKG_MANAGER="pacman"
        PKG_INSTALL_CMD="pacman -S --noconfirm --needed"
        ;;
    *)
        error "Unsupported distribution: $ID"
        echo "This installer supports: Fedora, Arch Linux"
        exit 1
        ;;
esac

success "Detected: $PRETTY_NAME ($DISTRO)"
echo

# ============================================================================
# FEATURE SELECTION
# ============================================================================

info "[2/14] Feature selection..."
echo

# Check if we're in update mode
if [ "$UPDATE_MODE" = true ]; then
    load_options
else
    # Interactive feature selection
# JumpCloud integration
# Check if JumpCloud PAM module is installed
JUMPCLOUD_DETECTED=false
if [ -f /lib/security/pam_jc_account_expiration.so ] || [ -f /usr/lib/security/pam_jc_account_expiration.so ]; then
    JUMPCLOUD_DETECTED=true
fi

if [ "$JUMPCLOUD_DETECTED" = true ]; then
    info "JumpCloud PAM module detected"
    read -p "Enable JumpCloud authentication integration? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_JUMPCLOUD=false
        info "  ✓ Standard PAM authentication"
    else
        ENABLE_JUMPCLOUD=true
        info "  ✓ JumpCloud integration enabled"
    fi
else
    ENABLE_JUMPCLOUD=false
    info "Standard PAM authentication (JumpCloud not installed)"
fi

echo
info "Additional authentication methods (optional):"

# Fingerprint authentication
read -p "Enable fingerprint reader support (fprintd)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENABLE_FINGERPRINT=true
    info "  ✓ Fingerprint authentication enabled"
else
    ENABLE_FINGERPRINT=false
fi

# U2F hardware tokens
read -p "Enable U2F hardware security keys (YubiKey, etc.)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENABLE_U2F=true
    info "  ✓ U2F hardware token support enabled"
else
    ENABLE_U2F=false
fi

# Google Authenticator 2FA
read -p "Enable Google Authenticator 2FA (TOTP)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENABLE_GOOGLE_AUTH=true
    info "  ✓ Google Authenticator 2FA enabled"
    warn "  Note: You must run setup-google-auth after installation"
else
    ENABLE_GOOGLE_AUTH=false
fi

# systemd-homed
read -p "Enable systemd-homed support (encrypted portable homes)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ENABLE_SYSTEMD_HOME=true
    info "  ✓ systemd-homed support enabled"
else
    ENABLE_SYSTEMD_HOME=false
fi

echo
info "Desktop integration (wallets/keyrings):"

# Detect GNOME Keyring
GNOME_KEYRING_DETECTED=false
case "$PKG_MANAGER" in
    dnf)
        if rpm -q gnome-keyring &>/dev/null; then
            GNOME_KEYRING_DETECTED=true
        fi
        ;;
    pacman)
        if pacman -Qi gnome-keyring &>/dev/null; then
            GNOME_KEYRING_DETECTED=true
        fi
        ;;
esac

# Prompt with smart default
if [ "$GNOME_KEYRING_DETECTED" = true ]; then
    info "  GNOME Keyring detected"
    read -p "Enable GNOME Keyring integration? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GNOME_KEYRING=false
        info "  ✓ GNOME Keyring disabled"
    else
        ENABLE_GNOME_KEYRING=true
        info "  ✓ GNOME Keyring enabled"
    fi
else
    read -p "Enable GNOME Keyring integration? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_GNOME_KEYRING=true
        info "  ✓ GNOME Keyring enabled (will be installed)"
    else
        ENABLE_GNOME_KEYRING=false
        info "  ✓ GNOME Keyring disabled"
    fi
fi

# Detect KDE Wallet
KDE_WALLET_DETECTED=false
case "$PKG_MANAGER" in
    dnf)
        if rpm -q kwallet-pam &>/dev/null; then
            KDE_WALLET_DETECTED=true
        fi
        ;;
    pacman)
        if pacman -Qi kwallet-pam &>/dev/null; then
            KDE_WALLET_DETECTED=true
        fi
        ;;
esac

# Prompt with smart default
if [ "$KDE_WALLET_DETECTED" = true ]; then
    info "  KDE Wallet detected"
    read -p "Enable KDE Wallet integration? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_KDE_WALLET=false
        info "  ✓ KDE Wallet disabled"
    else
        ENABLE_KDE_WALLET=true
        info "  ✓ KDE Wallet enabled"
    fi
else
    read -p "Enable KDE Wallet integration? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_KDE_WALLET=true
        info "  ✓ KDE Wallet enabled (will be installed)"
    else
        ENABLE_KDE_WALLET=false
        info "  ✓ KDE Wallet disabled"
    fi
fi

echo
# Game mode support - detect Steam installation for smart default
STEAM_DETECTED=false
case "$PKG_MANAGER" in
    dnf)
        if rpm -q steam &>/dev/null; then
            STEAM_DETECTED=true
        fi
        ;;
    pacman)
        if pacman -Qi steam &>/dev/null; then
            STEAM_DETECTED=true
        fi
        ;;
esac

if [ "$STEAM_DETECTED" = true ]; then
    info "Steam detected on system"
    read -p "Enable game mode auto-login support? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        ENABLE_GAME_MODE=false
        info "  ✓ Game mode disabled (desktop only)"
    else
        ENABLE_GAME_MODE=true
        info "  ✓ Game mode enabled"
    fi
else
    read -p "Enable game mode auto-login support? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE_GAME_MODE=true
        info "  ✓ Game mode enabled"
    else
        ENABLE_GAME_MODE=false
        info "  ✓ Game mode disabled (desktop only)"
    fi
fi

# Desktop environment - auto-detect installed sessions
echo
info "Detecting installed desktop environments..."

declare -a SESSION_NAMES
declare -a SESSION_COMMANDS
SESSION_COUNT=0

# Scan Wayland sessions
if [ -d /usr/share/wayland-sessions ]; then
    for desktop_file in /usr/share/wayland-sessions/*.desktop; do
        if [ -f "$desktop_file" ]; then
            name=$(grep "^Name=" "$desktop_file" 2>/dev/null | cut -d= -f2 || true)
            exec_cmd=$(grep "^Exec=" "$desktop_file" 2>/dev/null | cut -d= -f2 || true)
            if [ -n "$name" ] && [ -n "$exec_cmd" ]; then
                SESSION_NAMES+=("$name")
                SESSION_COMMANDS+=("$exec_cmd")
                SESSION_COUNT=$((SESSION_COUNT + 1))
            fi
        fi
    done
fi

# Scan X11 sessions
if [ -d /usr/share/xsessions ]; then
    for desktop_file in /usr/share/xsessions/*.desktop; do
        if [ -f "$desktop_file" ]; then
            name=$(grep "^Name=" "$desktop_file" 2>/dev/null | cut -d= -f2 || true)
            exec_cmd=$(grep "^Exec=" "$desktop_file" 2>/dev/null | cut -d= -f2 || true)
            if [ -n "$name" ] && [ -n "$exec_cmd" ]; then
                SESSION_NAMES+=("$name (X11)")
                SESSION_COMMANDS+=("$exec_cmd")
                SESSION_COUNT=$((SESSION_COUNT + 1))
            fi
        fi
    done
fi

if [ $SESSION_COUNT -eq 0 ]; then
    warn "No desktop sessions found in /usr/share/{wayland-sessions,xsessions}"
    info "Enter session command manually:"
    read -p "Desktop command [Hyprland]: " DESKTOP_ENV
    DESKTOP_ENV="${DESKTOP_ENV:-Hyprland}"
else
    info "Found $SESSION_COUNT installed session(s):"
    echo
    for i in "${!SESSION_NAMES[@]}"; do
        echo "  $((i+1)). ${SESSION_NAMES[$i]}"
    done
    echo
    read -p "Select default session [1]: " SESSION_CHOICE
    SESSION_CHOICE="${SESSION_CHOICE:-1}"

    if [[ "$SESSION_CHOICE" =~ ^[0-9]+$ ]] && [ "$SESSION_CHOICE" -ge 1 ] && [ "$SESSION_CHOICE" -le "$SESSION_COUNT" ]; then
        DESKTOP_ENV="${SESSION_COMMANDS[$((SESSION_CHOICE-1))]}"
        info "  ✓ Selected: ${SESSION_NAMES[$((SESSION_CHOICE-1))]}"
    else
        warn "Invalid selection, using first session"
        DESKTOP_ENV="${SESSION_COMMANDS[0]}"
        info "  ✓ Selected: ${SESSION_NAMES[0]}"
    fi
fi

info "  ✓ Default session command: $DESKTOP_ENV"

# Auto-login user (only if game mode enabled)
if [ "$ENABLE_GAME_MODE" = true ]; then
    echo
    info "Game mode auto-login user:"
    read -p "Username [$ACTUAL_USER]: " AUTOLOGIN_USER
    AUTOLOGIN_USER="${AUTOLOGIN_USER:-$ACTUAL_USER}"
    info "  ✓ Auto-login user: $AUTOLOGIN_USER"
fi

fi  # End of UPDATE_MODE check

echo
info "Configuration summary:"
info "  - Distribution: $DISTRO"
info "  - Authentication:"
info "      Base: $([ "$ENABLE_JUMPCLOUD" = true ] && echo "JumpCloud" || echo "Standard UNIX")"
[ "$ENABLE_FINGERPRINT" = true ] && info "      Fingerprint: enabled"
[ "$ENABLE_U2F" = true ] && info "      U2F tokens: enabled"
[ "$ENABLE_GOOGLE_AUTH" = true ] && info "      Google Auth 2FA: enabled"
[ "$ENABLE_SYSTEMD_HOME" = true ] && info "      systemd-homed: enabled"
info "  - Desktop integration:"
[ "$ENABLE_GNOME_KEYRING" = true ] && info "      GNOME Keyring: enabled"
[ "$ENABLE_KDE_WALLET" = true ] && info "      KDE Wallet: enabled"
info "  - Game mode: $([ "$ENABLE_GAME_MODE" = true ] && echo "enabled" || echo "disabled")"
info "  - Desktop: $DESKTOP_ENV"
[ "$ENABLE_GAME_MODE" = true ] && info "  - Game user: $AUTOLOGIN_USER"
echo

read -p "Proceed with installation? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Installation cancelled."
    exit 0
fi

# ============================================================================
# PACKAGE INSTALLATION
# ============================================================================

info "[3/14] Determining required packages..."

# Base packages needed for all configurations
BASE_PACKAGES=()
case "$DISTRO" in
    fedora)
        BASE_PACKAGES+=("greetd" "jq" "socat")
        # regreet requires COPR on Fedora
        info "regreet requires COPR repository on Fedora"
        info "Enabling COPR: psoldunov/regreet"

        if dnf copr enable -y psoldunov/regreet; then
            success "COPR repository enabled"
            BASE_PACKAGES+=("regreet")
        else
            error "Failed to enable COPR repository"
            read -p "Continue without regreet? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        ;;
    arch)
        BASE_PACKAGES+=("greetd" "greetd-regreet" "swaybg" "jq" "socat")
        ;;
esac

# Add Hyprland if not already installed (required for regreet)
info "Checking for Hyprland..."
case "$DISTRO" in
    fedora)
        if ! rpm -q hyprland &>/dev/null; then
            warn "Hyprland not found - required for regreet"
            read -p "Install Hyprland? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                BASE_PACKAGES+=("hyprland")
            fi
        fi
        ;;
    arch)
        if ! pacman -Qi hyprland &>/dev/null && ! pacman -Qi hyprland-git &>/dev/null; then
            warn "Hyprland not found - required for regreet"
            read -p "Install Hyprland? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                BASE_PACKAGES+=("hyprland")
            fi
        fi
        ;;
esac

# Add GNOME Keyring if enabled
if [ "$ENABLE_GNOME_KEYRING" = true ]; then
    BASE_PACKAGES+=("gnome-keyring")
fi

# Game mode packages
GAME_PACKAGES=()
if [ "$ENABLE_GAME_MODE" = true ]; then
    case "$DISTRO" in
        fedora)
            GAME_PACKAGES+=("gamescope" "steam")
            ;;
        arch)
            GAME_PACKAGES+=("gamescope" "steam")
            ;;
    esac
fi

# PAM authentication packages
PAM_PACKAGES=()

if [ "$ENABLE_FINGERPRINT" = true ]; then
    PAM_PACKAGES+=("fprintd")
fi

if [ "$ENABLE_U2F" = true ]; then
    case "$DISTRO" in
        fedora)
            PAM_PACKAGES+=("pam-u2f")
            ;;
        arch)
            PAM_PACKAGES+=("pam-u2f")
            ;;
    esac
fi

if [ "$ENABLE_GOOGLE_AUTH" = true ]; then
    case "$DISTRO" in
        fedora)
            PAM_PACKAGES+=("google-authenticator")
            ;;
        arch)
            PAM_PACKAGES+=("libpam-google-authenticator")
            ;;
    esac
fi

if [ "$ENABLE_KDE_WALLET" = true ]; then
    case "$DISTRO" in
        fedora)
            PAM_PACKAGES+=("kwallet-pam")
            ;;
        arch)
            PAM_PACKAGES+=("kwallet-pam")
            ;;
    esac
fi

# Note: systemd-homed support is built into systemd, no extra package needed
# Note: pam_systemd and pam_faillock are built into systemd/pam, no extra package needed

# Combine packages
ALL_PACKAGES=("${BASE_PACKAGES[@]}" "${GAME_PACKAGES[@]}" "${PAM_PACKAGES[@]}")

# Handle package conflicts and alternatives
info "Checking for package conflicts..."
FILTERED_PACKAGES=()

for pkg in "${ALL_PACKAGES[@]}"; do
    SKIP_PACKAGE=false

    case "$DISTRO" in
        arch)
            # Check for greetd variants (greetd-git, greetd-bin, etc.)
            if [ "$pkg" = "greetd" ]; then
                if pacman -Qq | grep -q "^greetd"; then
                    info "  greetd variant already installed, skipping official greetd package"
                    SKIP_PACKAGE=true
                fi
            fi

            # Check for regreet variants (greetd-regreet-git, etc.)
            if [ "$pkg" = "greetd-regreet" ]; then
                if pacman -Qq | grep -q "^greetd-regreet"; then
                    info "  greetd-regreet variant already installed, skipping official package"
                    SKIP_PACKAGE=true
                fi
            fi

            # Check if package is already installed
            if pacman -Qi "$pkg" &>/dev/null; then
                info "  $pkg already installed, skipping"
                SKIP_PACKAGE=true
            fi
            ;;
        fedora)
            # Check if package is already installed
            if rpm -q "$pkg" &>/dev/null; then
                info "  $pkg already installed, skipping"
                SKIP_PACKAGE=true
            fi
            ;;
    esac

    if [ "$SKIP_PACKAGE" = false ]; then
        FILTERED_PACKAGES+=("$pkg")
    fi
done

ALL_PACKAGES=("${FILTERED_PACKAGES[@]}")

# Verify packages exist
info "Verifying package availability..."
MISSING_PACKAGES=()

for pkg in "${ALL_PACKAGES[@]}"; do
    case "$PKG_MANAGER" in
        dnf)
            if ! dnf info "$pkg" &>/dev/null; then
                MISSING_PACKAGES+=("$pkg")
            fi
            ;;
        pacman)
            if ! pacman -Si "$pkg" &>/dev/null; then
                MISSING_PACKAGES+=("$pkg")
            fi
            ;;
    esac
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    warn "The following packages are not available:"
    for pkg in "${MISSING_PACKAGES[@]}"; do
        echo "  - $pkg"
    done
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation cancelled due to missing packages"
        exit 1
    fi
fi

info "[4/14] Installing packages..."

if [ ${#ALL_PACKAGES[@]} -eq 0 ]; then
    info "All required packages already installed, skipping"
else
    echo "Packages: ${ALL_PACKAGES[*]}"

    if $PKG_INSTALL_CMD "${ALL_PACKAGES[@]}"; then
        success "Packages installed successfully"
    else
        warn "Some packages may have failed to install"
        read -p "Continue with installation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# ============================================================================
# USER AND DIRECTORY SETUP
# ============================================================================

info "[5/14] Creating greeter user..."
if ! id -u greeter >/dev/null 2>&1; then
    useradd -r -s /sbin/nologin greeter
    success "Greeter user created"
else
    info "Greeter user already exists"
fi

# Add greeter to necessary groups
if [ "$ENABLE_GAME_MODE" = true ]; then
    usermod -a -G input,video greeter
    info "Greeter user added to input and video groups"
fi

# ============================================================================
# BACKUP AND CLEAN EXISTING CONFIGS
# ============================================================================

info "[6/14] Backing up and cleaning existing configurations..."

# Create full backup of /etc/greetd directory if it exists
if [ -d /etc/greetd ]; then
    BACKUP_FILE="/etc/greetd_backup_$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" -C /etc greetd 2>/dev/null || true
    if [ -f "$BACKUP_FILE" ]; then
        info "  Backed up /etc/greetd → $BACKUP_FILE"
    fi

    # Remove entire directory for clean installation
    rm -rf /etc/greetd
    info "  Removed old /etc/greetd directory"
fi

# Backup PAM config
if [ -f /etc/pam.d/greetd ]; then
    cp /etc/pam.d/greetd "/etc/pam.d/greetd.bak.$(date +%Y%m%d-%H%M%S)"
    info "  Backed up /etc/pam.d/greetd"
fi

success "Backup complete, ready for clean installation"

# ============================================================================
# CREATE DIRECTORY STRUCTURE
# ============================================================================

info "[7/14] Creating directory structure..."
mkdir -p /etc/greetd/css
mkdir -p /etc/greetd/scripts
mkdir -p /etc/greetd/logs
mkdir -p /var/lib/greetd

chown greeter:greeter /etc/greetd/logs
chown greeter:greeter /var/lib/greetd
chmod 750 /etc/greetd/logs

success "Directories created"

# ============================================================================
# DEPLOY CONFIGURATION FILES
# ============================================================================

info "[8/14] Installing desktop mode configuration..."

# Check if Hyprland is available
HYPRLAND_CMD=""
if command -v Hyprland &>/dev/null; then
    HYPRLAND_CMD="Hyprland"
elif [ -f /usr/bin/Hyprland ]; then
    HYPRLAND_CMD="/usr/bin/Hyprland"
else
    warn "Hyprland not found - regreet requires a Wayland compositor"
    info "Please install Hyprland or another compositor before running greetd"
fi

# Create mode-desktop.toml with Hyprland + regreet
cat > /etc/greetd/mode-desktop.toml <<EOF
[terminal]
# The VT to run the greeter on. Can be "next", "current" or a number
vt = 1

[default_session]
# regreet - GTK4 greeter running under Hyprland compositor
# Hyprland config: /etc/greetd/hypr.conf
# regreet config: /etc/greetd/regreet.toml
command = "${HYPRLAND_CMD:-Hyprland} --config /etc/greetd/hypr.conf"

# The user to run the greeter as
user = "greeter"
EOF

chown root:root /etc/greetd/mode-desktop.toml
chmod 644 /etc/greetd/mode-desktop.toml
success "Desktop mode config installed"

info "[9/14] Installing regreet configuration and assets..."

# Install Hyprland config for greeter
cp "$SCRIPT_DIR/config/hypr.conf" /etc/greetd/hypr.conf
chown root:greeter /etc/greetd/hypr.conf
chmod 644 /etc/greetd/hypr.conf
success "Hyprland greeter config installed"

# Install regreet config
cp "$SCRIPT_DIR/config/regreet.toml" /etc/greetd/regreet.toml
chown root:greeter /etc/greetd/regreet.toml
chmod 644 /etc/greetd/regreet.toml
success "ReGreet config installed"

# Install regreet CSS for transparent window
cp "$SCRIPT_DIR/config/regreet.css" /etc/greetd/regreet.css
chown root:greeter /etc/greetd/regreet.css
chmod 644 /etc/greetd/regreet.css
success "ReGreet CSS installed"

# Install regreet launcher script (mouse follow feature)
cp "$SCRIPT_DIR/config/regreet-launcher.sh" /etc/greetd/regreet-launcher.sh
chown root:greeter /etc/greetd/regreet-launcher.sh
chmod 755 /etc/greetd/regreet-launcher.sh
success "ReGreet launcher script installed"

# Install wallpaper/background
cp "$SCRIPT_DIR/assets/wallpaper.png" /etc/greetd/bg.png
chown root:greeter /etc/greetd/bg.png
chmod 644 /etc/greetd/bg.png
success "Background image installed"

info "[10/14] Generating PAM configuration..."

# Function to generate PAM config from snippets
generate_pam_config() {
    local output_file="/etc/pam.d/greetd"
    local distro_snippets="$SCRIPT_DIR/config/pam-snippets/$DISTRO"
    local common_snippets="$SCRIPT_DIR/config/pam-snippets"

    echo "#%PAM-1.0" > "$output_file"
    echo "# Dynamically generated PAM configuration for greetd" >> "$output_file"
    echo "# Generated by greetd installer on $(date)" >> "$output_file"
    echo >> "$output_file"

    # AUTH STACK
    echo "# ============================================================================" >> "$output_file"
    echo "# Authentication" >> "$output_file"
    echo "# ============================================================================" >> "$output_file"
    cat "$common_snippets/auth-base-preauth.conf" >> "$output_file"

    # JumpCloud (if enabled)
    if [ "$ENABLE_JUMPCLOUD" = true ]; then
        cat "$common_snippets/auth-jumpcloud.conf" >> "$output_file"
    fi

    # Alternative auth methods (fingerprint, U2F) - these come before password
    if [ "$ENABLE_FINGERPRINT" = true ]; then
        cat "$common_snippets/auth-fingerprint.conf" >> "$output_file"
    fi

    if [ "$ENABLE_U2F" = true ]; then
        cat "$common_snippets/auth-u2f.conf" >> "$output_file"
    fi

    # Standard password auth (always included)
    cat "$common_snippets/auth-unix.conf" >> "$output_file"

    # GNOME Keyring unlock (if enabled)
    if [ "$ENABLE_GNOME_KEYRING" = true ]; then
        cat "$common_snippets/keyring-gnome.conf" >> "$output_file"
    fi

    # Google Authenticator 2FA (if enabled - comes after password)
    if [ "$ENABLE_GOOGLE_AUTH" = true ]; then
        cat "$common_snippets/auth-google-authenticator.conf" >> "$output_file"
    fi

    # Auth postauth (faillock + deny)
    cat "$common_snippets/auth-postauth.conf" >> "$output_file"
    echo >> "$output_file"

    # ACCOUNT STACK
    echo "# ============================================================================" >> "$output_file"
    echo "# Account" >> "$output_file"
    echo "# ============================================================================" >> "$output_file"
    if [ "$ENABLE_SYSTEMD_HOME" = true ]; then
        cat "$common_snippets/account-systemd-home.conf" >> "$output_file"
    fi
    cat "$common_snippets/account-base.conf" >> "$output_file"
    echo >> "$output_file"

    # PASSWORD STACK
    echo "# ============================================================================" >> "$output_file"
    echo "# Password" >> "$output_file"
    echo "# ============================================================================" >> "$output_file"
    if [ "$ENABLE_SYSTEMD_HOME" = true ]; then
        cat "$common_snippets/password-systemd-home.conf" >> "$output_file"
    fi
    cat "$common_snippets/password-base.conf" >> "$output_file"
    if [ "$ENABLE_GNOME_KEYRING" = true ]; then
        cat "$common_snippets/password-gnome-keyring.conf" >> "$output_file"
    fi
    echo >> "$output_file"

    # SESSION STACK
    echo "# ============================================================================" >> "$output_file"
    echo "# Session" >> "$output_file"
    echo "# ============================================================================" >> "$output_file"
    cat "$distro_snippets/session-base.conf" >> "$output_file"

    # systemd session (always included - critical)
    cat "$common_snippets/session-systemd.conf" >> "$output_file"

    # systemd-homed session
    if [ "$ENABLE_SYSTEMD_HOME" = true ]; then
        cat "$common_snippets/session-systemd-home.conf" >> "$output_file"
    fi

    # Keyring/wallet unlock
    if [ "$ENABLE_GNOME_KEYRING" = true ]; then
        cat "$common_snippets/session-gnome-keyring.conf" >> "$output_file"
    fi

    if [ "$ENABLE_KDE_WALLET" = true ]; then
        cat "$common_snippets/session-kwallet.conf" >> "$output_file"
    fi

    # Lastlog
    cat "$distro_snippets/session-lastlog.conf" >> "$output_file"
}

# Verify JumpCloud if enabled
if [ "$ENABLE_JUMPCLOUD" = true ]; then
    if [ ! -f /lib/security/pam_jc_account_expiration.so ] && [ ! -f /usr/lib/security/pam_jc_account_expiration.so ]; then
        warn "JumpCloud PAM module not found!"
        echo "Expected location: /lib/security/pam_jc_account_expiration.so"
        echo "Install JumpCloud agent or authentication will fail."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Generate PAM config
generate_pam_config

chown root:root /etc/pam.d/greetd
chmod 644 /etc/pam.d/greetd

success "PAM config generated with selected features"

info "[11/14] Installing helper scripts..."
cp "$SCRIPT_DIR/scripts/sync-keyring-password" /etc/greetd/scripts/sync-keyring-password
chmod +x /etc/greetd/scripts/sync-keyring-password
success "Keyring sync script installed"

if [ "$ENABLE_GAME_MODE" = true ]; then
    cp "$SCRIPT_DIR/scripts/game-mode-wrapper.sh" /etc/greetd/scripts/game-mode-wrapper.sh
    chmod +x /etc/greetd/scripts/game-mode-wrapper.sh
    success "Game mode wrapper installed"
fi

if [ "$ENABLE_FINGERPRINT" = true ]; then
    cp "$SCRIPT_DIR/scripts/setup-fingerprint" /etc/greetd/scripts/setup-fingerprint
    chmod +x /etc/greetd/scripts/setup-fingerprint
    success "Fingerprint setup script installed"
fi

if [ "$ENABLE_U2F" = true ]; then
    cp "$SCRIPT_DIR/scripts/setup-u2f" /etc/greetd/scripts/setup-u2f
    chmod +x /etc/greetd/scripts/setup-u2f
    success "U2F setup script installed"
fi

if [ "$ENABLE_GOOGLE_AUTH" = true ]; then
    cp "$SCRIPT_DIR/scripts/setup-google-auth" /etc/greetd/scripts/setup-google-auth
    chmod +x /etc/greetd/scripts/setup-google-auth
    success "Google Authenticator setup script installed"
fi

info "[12/14] Installing environments file..."
cp "$SCRIPT_DIR/config/environments" /etc/greetd/environments
chown greeter:greeter /etc/greetd/environments
chmod 644 /etc/greetd/environments
success "Environments file installed"

# ============================================================================
# GAME MODE SETUP (CONDITIONAL)
# ============================================================================

if [ "$ENABLE_GAME_MODE" = true ]; then
    info "[13/14] Setting up game mode..."

    # Create mode-game.toml with substituted username
    cat > /etc/greetd/mode-game.toml <<EOF
[terminal]
vt = 1
[default_session]
# command = "steam -tenfoot"
command = "/usr/bin/gamescope -e -- /usr/bin/steam -gamepadui"
# command = "/etc/greetd/scripts/game-mode-wrapper.sh"
user = "$AUTOLOGIN_USER"
autologin = true
EOF

    chown root:root /etc/greetd/mode-game.toml
    chmod 644 /etc/greetd/mode-game.toml
    success "Game mode config created for user: $AUTOLOGIN_USER"

    # Install game-mode systemd service if binary exists
    if [ -f /usr/local/bin/game-mode ]; then
        cp "$SCRIPT_DIR/systemd/game-mode.service" /etc/systemd/system/game-mode.service
        chmod 644 /etc/systemd/system/game-mode.service
        systemctl daemon-reload
        systemctl enable game-mode.service
        success "Game mode service installed and enabled"
    else
        warn "game-mode binary not found at /usr/local/bin/game-mode"
        echo "Game mode service will NOT be installed."
        echo "To add later:"
        echo "  1. Place binary at /usr/local/bin/game-mode"
        echo "  2. Run: systemctl enable /etc/systemd/system/game-mode.service"
    fi

    # Create symlink to desktop mode (default)
    ln -sf /etc/greetd/mode-desktop.toml /etc/greetd/config.toml
    success "Default mode: desktop (use guide button to switch)"
else
    info "[13/14] Skipping game mode setup (disabled)"

    # Link directly to desktop mode (no switching)
    ln -sf /etc/greetd/mode-desktop.toml /etc/greetd/config.toml
    success "Desktop mode configured (game mode disabled)"
fi

# ============================================================================
# DISPLAY MANAGER CONFIGURATION
# ============================================================================

info "[14/14] Configuring display manager..."

# Detect existing display manager
EXISTING_DM=""
for dm in lightdm gdm sddm lxdm; do
    if systemctl is-enabled ${dm}.service >/dev/null 2>&1; then
        EXISTING_DM="$dm"
        break
    fi
done

if [ -n "$EXISTING_DM" ]; then
    warn "Detected existing display manager: $EXISTING_DM"
    read -p "Disable $EXISTING_DM and enable greetd? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl disable ${EXISTING_DM}.service
        systemctl enable greetd.service
        success "greetd enabled, $EXISTING_DM disabled"
    else
        info "Skipping service configuration. To enable manually:"
        echo "  systemctl disable ${EXISTING_DM}.service"
        echo "  systemctl enable greetd.service"
    fi
else
    systemctl enable greetd.service
    success "greetd enabled"
fi

# ============================================================================
# INSTALLATION COMPLETE
# ============================================================================

echo
success "==> Installation complete!"

# Save installation options for future updates
save_options

echo

info "Configuration summary:"
info "  - Distribution: $PRETTY_NAME"
info "  - Greeter: regreet (GTK4 graphical greeter with Hyprland compositor)"
info "  - Authentication: $([ "$ENABLE_JUMPCLOUD" = true ] && echo "JumpCloud + keyring sync" || echo "Standard PAM + keyring sync")"
info "  - Default session: $DESKTOP_ENV"
echo
info "Greeter features:"
info "  - Background image: /etc/greetd/bg.png"
info "  - Session auto-discovery from /usr/share/{wayland-sessions,xsessions}"
info "  - Configuration: /etc/greetd/regreet.toml"
info "  - Hyprland config: /etc/greetd/hypr.conf"

# Post-install setup instructions for authentication methods
NEEDS_SETUP=false

if [ "$ENABLE_FINGERPRINT" = true ]; then
    NEEDS_SETUP=true
fi

if [ "$ENABLE_U2F" = true ]; then
    NEEDS_SETUP=true
fi

if [ "$ENABLE_GOOGLE_AUTH" = true ]; then
    NEEDS_SETUP=true
fi

if [ "$NEEDS_SETUP" = true ]; then
    echo
    warn "IMPORTANT: Additional setup required!"
    echo
    info "You enabled authentication methods that require per-user configuration."
    info "After activating greetd, run these setup scripts AS YOUR USER (not root):"
    echo

    if [ "$ENABLE_FINGERPRINT" = true ]; then
        info "  Fingerprint:"
        echo "    /etc/greetd/scripts/setup-fingerprint"
        [ "$ENABLE_FINGERPRINT" = true ] && info "    Then start fprintd: sudo systemctl enable --now fprintd.service"
    fi

    if [ "$ENABLE_U2F" = true ]; then
        info "  U2F hardware tokens:"
        echo "    /etc/greetd/scripts/setup-u2f"
    fi

    if [ "$ENABLE_GOOGLE_AUTH" = true ]; then
        info "  Google Authenticator 2FA:"
        echo "    /etc/greetd/scripts/setup-google-auth"
    fi

    echo
    warn "Test login in a separate terminal before logging out!"
fi

if [ "$ENABLE_GAME_MODE" = true ]; then
    echo
    info "Game mode:"
    info "  - Enabled for user: $AUTOLOGIN_USER"
    info "  - Automatic switch: Press gamepad guide button at login"
    info "  - Manual switch to game:"
    echo "      sudo ln -sf /etc/greetd/mode-game.toml /etc/greetd/config.toml"
    echo "      sudo systemctl restart greetd"
    info "  - Manual switch to desktop:"
    echo "      sudo ln -sf /etc/greetd/mode-desktop.toml /etc/greetd/config.toml"
    echo "      sudo systemctl restart greetd"
fi

echo
info "To activate greetd:"
info "  - Reboot, OR"
if [ -n "$EXISTING_DM" ]; then
    info "  - systemctl stop $EXISTING_DM && systemctl start greetd"
else
    info "  - systemctl start greetd"
fi
echo
