#!/bin/bash
set -e

echo "Installing required fonts..."

FONTS_DIR="$HOME/.local/share/fonts"
REPOS_DIR="$HOME/repos"

# Create fonts directory if it doesn't exist
mkdir -p "$FONTS_DIR"
mkdir -p "$REPOS_DIR"

# Install SF Pro fonts (Apple fonts)
echo "Installing SF Pro fonts..."
SF_PRO_DIR="$REPOS_DIR/SF-Pro"
if [ ! -d "$SF_PRO_DIR" ]; then
    git clone https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git "$SF_PRO_DIR"
fi
cp "$SF_PRO_DIR"/*.otf "$FONTS_DIR/" 2>/dev/null || true

# Install Lilex font
echo "Installing Lilex font..."
LILEX_URL="https://github.com/mishamyrt/Lilex/releases/download/2.621/Lilex.zip"
LILEX_ZIP="$REPOS_DIR/Lilex.zip"
curl -fLo "$LILEX_ZIP" "$LILEX_URL"
unzip -o "$LILEX_ZIP" -d "$FONTS_DIR/Lilex" "*.ttf" "*.otf" 2>/dev/null || true
rm "$LILEX_ZIP"

# Install Nerd Fonts (FiraCode and JetBrains Mono)
echo "Installing FiraCode Nerd Font..."
FIRA_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
FIRA_ZIP="$REPOS_DIR/FiraCode.zip"
curl -fLo "$FIRA_ZIP" "$FIRA_URL"
unzip -o "$FIRA_ZIP" -d "$FONTS_DIR/FiraCode" "*.ttf" "*.otf" 2>/dev/null || true
rm "$FIRA_ZIP"

echo "Installing JetBrains Mono Nerd Font..."
JETBRAINS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
JETBRAINS_ZIP="$REPOS_DIR/JetBrainsMono.zip"
curl -fLo "$JETBRAINS_ZIP" "$JETBRAINS_URL"
unzip -o "$JETBRAINS_ZIP" -d "$FONTS_DIR/JetBrainsMono" "*.ttf" "*.otf" 2>/dev/null || true
rm "$JETBRAINS_ZIP"

# Install Powerline fonts
echo "Installing Powerline fonts..."
POWERLINE_DIR="$REPOS_DIR/powerline-fonts"
if [ ! -d "$POWERLINE_DIR" ]; then
    git clone https://github.com/powerline/fonts.git "$POWERLINE_DIR" --depth=1
fi
cd "$POWERLINE_DIR"
./install.sh
cd -

# Noto Sans is typically available via system package manager
# Check if it exists, if not provide instructions
if ! fc-list | grep -qi "noto sans"; then
    echo "WARNING: Noto Sans not found. Install via system package manager:"
    echo "  Fedora/RHEL: sudo dnf install google-noto-sans-fonts"
    echo "  Debian/Ubuntu: sudo apt install fonts-noto"
    echo "  Arch: sudo pacman -S noto-fonts"
fi

# Refresh font cache
echo "Refreshing font cache..."
fc-cache -fv

echo "Font installation complete!"
echo "Installed fonts:"
fc-list | grep -iE "lilex|sf pro|firacode nerd|jetbrains.*nerd|noto sans|powerline" | cut -d: -f2 | sort -u
