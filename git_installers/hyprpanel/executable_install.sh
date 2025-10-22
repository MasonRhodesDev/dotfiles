#!/bin/bash
set -e

if command -v dnf > /dev/null 2>&1; then
    PKG_MGR="dnf"
elif command -v pacman > /dev/null 2>&1; then
    PKG_MGR="pacman"
else
    echo "Unsupported platform"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/HyprPanel"

echo "Installing HyprPanel build dependencies..."

if [ "$PKG_MGR" = "dnf" ]; then
    sudo dnf install -y --skip-unavailable \
        meson ninja-build \
        gtk3-devel \
        gtk4-devel \
        gtksourceview3-devel \
        libgtop2-devel \
        libsoup3-devel \
        wireplumber-devel \
        bluez-libs-devel \
        NetworkManager-libnm-devel \
        sassc \
        wl-clipboard \
        upower-devel \
        gvfs

    echo "Installing AGS v3 dependencies..."
    sudo dnf install -y --skip-unavailable \
        golang gobject-introspection-devel \
        gtk-layer-shell-devel gtk4-layer-shell-devel

    sudo dnf install -y --skip-unavailable \
        astal astal-gjs astal-gtk4 astal-io astal-libs
        
elif [ "$PKG_MGR" = "pacman" ]; then
    sudo pacman -S --needed --noconfirm \
        meson ninja \
        gtk3 \
        gtk4 \
        gtksourceview3 \
        libgtop \
        libsoup3 \
        wireplumber \
        bluez-libs \
        networkmanager \
        sassc \
        wl-clipboard \
        upower \
        gvfs

    echo "Installing AGS v3 dependencies..."
    sudo pacman -S --needed --noconfirm \
        go gobject-introspection \
        gtk-layer-shell gtk4-layer-shell
fi

# Install AGS v3 if not present or wrong version
AGS_VERSION=$(ags --version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "0.0.0")
if [[ "$AGS_VERSION" != "3.0.0" ]]; then
    echo "Installing AGS v3..."
    
    # Remove old AGS v2 if present
    if rpm -q aylurs-gtk-shell2 &>/dev/null; then
        sudo dnf remove -y aylurs-gtk-shell2
    fi
    
    # Build and install AGS v3 from source
    cd /tmp
    if [ -d "ags" ]; then
        rm -rf ags
    fi
    
    git clone --recurse-submodules https://github.com/aylur/ags
    cd ags
    meson setup build
    sudo meson install -C build
    cd ..
    rm -rf ags
fi

# Clone or update the repository
if [ -d "$REPO_DIR" ]; then
    echo "Updating existing HyprPanel repository..."
    cd "$REPO_DIR"
    git pull origin master
else
    echo "Cloning HyprPanel repository..."
    git clone https://github.com/Jas-SinghFSU/HyprPanel.git "$REPO_DIR"
    cd "$REPO_DIR"
fi

# Install npm dependencies first
echo "Installing npm dependencies..."
npm install

# Build and install
echo "Building HyprPanel..."
if [ -d "build" ]; then
    rm -rf build
fi

meson setup build
meson compile -C build

echo "Installing HyprPanel..."
sudo meson install -C build

echo "HyprPanel installed successfully!"
echo "You can now run 'hyprpanel' to start the panel."