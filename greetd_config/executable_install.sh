#!/bin/bash
# greetd installation script with ReGreet and keyring sync
# Requires root privileges

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER="${WALLPAPER_PATH:-$HOME/Pictures/forrest.png}"

echo "==> Installing greetd with Material Design ReGreet theme"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    echo "Usage: sudo ./install.sh"
    exit 1
fi

# Detect the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

echo "[1/8] Installing required packages..."
dnf install -y greetd gtkgreet gnome-keyring

echo "[2/8] Creating greeter user..."
if ! id -u greeter >/dev/null 2>&1; then
    useradd -r -s /sbin/nologin greeter
fi

echo "[3/8] Copying wallpaper..."
mkdir -p /var/lib/greetd
if [ -f "$WALLPAPER" ]; then
    cp "$WALLPAPER" /var/lib/greetd/wallpaper.png
    chown greeter:greeter /var/lib/greetd/wallpaper.png
    echo "Wallpaper copied from: $WALLPAPER"
else
    echo "WARNING: Wallpaper not found at $WALLPAPER"
    echo "Default wallpaper will be used"
fi

echo "[4/8] Installing greetd configuration..."
cp "$SCRIPT_DIR/config/greetd.toml" /etc/greetd/config.toml
chown root:root /etc/greetd/config.toml
chmod 644 /etc/greetd/config.toml

echo "[5/8] Installing gtkgreet CSS configuration..."
mkdir -p /etc/greetd
cp "$SCRIPT_DIR/config/gtkgreet.css" /etc/greetd/gtkgreet.css
chown greeter:greeter /etc/greetd/gtkgreet.css
chmod 644 /etc/greetd/gtkgreet.css

echo "[6/8] Installing Material Design CSS theme..."
mkdir -p /etc/greetd/css
cp "$SCRIPT_DIR/themes/regreet.css" /etc/greetd/css/regreet.css
chown greeter:greeter /etc/greetd/css/regreet.css
chmod 644 /etc/greetd/css/regreet.css

echo "[7/8] Installing PAM configuration with keyring sync..."
cp "$SCRIPT_DIR/config/pam-greetd" /etc/pam.d/greetd
chown root:root /etc/pam.d/greetd
chmod 644 /etc/pam.d/greetd

echo "[8/8] Configuring display manager..."
# Detect existing display manager
EXISTING_DM=""
for dm in lightdm gdm sddm lxdm; do
    if systemctl is-enabled ${dm}.service >/dev/null 2>&1; then
        EXISTING_DM="$dm"
        break
    fi
done

if [ -n "$EXISTING_DM" ]; then
    echo "Detected existing display manager: $EXISTING_DM"
    read -p "Disable $EXISTING_DM and enable greetd? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        systemctl disable ${EXISTING_DM}.service
        systemctl enable greetd.service
        echo "greetd enabled. $EXISTING_DM disabled."
    else
        echo "Skipping service configuration. You'll need to manually:"
        echo "  systemctl disable ${EXISTING_DM}.service"
        echo "  systemctl enable greetd.service"
    fi
else
    systemctl enable greetd.service
    echo "greetd enabled."
fi

echo
echo "==> Installation complete!"
echo
echo "To activate greetd, reboot or run:"
echo "  systemctl stop <your-current-display-manager>"
echo "  systemctl start greetd"
echo
echo "Note: Ensure your keyring password matches your login password"
echo "for automatic unlock. If they differ, you'll be prompted to unlock"
echo "the keyring after login."
echo
