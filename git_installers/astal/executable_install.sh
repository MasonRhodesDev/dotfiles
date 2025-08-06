#!/bin/bash
set -e

INSTALL_DIR="$HOME/git_installers/astal"
REPO_URL="https://github.com/aylur/astal.git"

# Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone or update the repository
if [ -d "astal" ]; then
    echo "Updating existing astal repository..."
    cd astal
    git pull origin main
else
    echo "Cloning astal repository..."
    git clone "$REPO_URL" astal
    cd astal
fi

echo "Installing dependencies..."
sudo dnf install -y \
  meson vala valadoc gobject-introspection-devel wayland-protocols-devel \
  gtk3-devel gtk-layer-shell-devel \
  gtk4-devel gtk4-layer-shell-devel

echo "Building and installing astal-io dependency..."
cd lib/astal/io
if [ -d "build" ]; then
    rm -rf build
fi
meson setup build
sudo meson install -C build

echo "Building and installing Astal3..."
cd ../gtk3
if [ -d "build" ]; then
    rm -rf build
fi
meson setup build
sudo meson install -C build

echo "Building and installing Astal4..."
cd ../gtk4
if [ -d "build" ]; then
    rm -rf build
fi
meson setup build
sudo meson install -C build

echo "Astal3 and Astal4 installation completed successfully!"
echo "Repository location: $INSTALL_DIR/astal"