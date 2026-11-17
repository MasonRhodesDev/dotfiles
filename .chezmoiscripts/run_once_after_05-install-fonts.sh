#!/bin/bash
set -e

echo "Installing required fonts..."

FONTS_DIR="$HOME/.local/share/fonts"
REPOS_DIR="$HOME/repos"

mkdir -p "$FONTS_DIR"
mkdir -p "$REPOS_DIR"

echo "Installing SF Pro fonts..."
SF_PRO_DIR="$REPOS_DIR/SF-Pro"
if [ ! -d "$SF_PRO_DIR" ]; then
    git clone https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts.git "$SF_PRO_DIR"
fi
cp "$SF_PRO_DIR"/*.otf "$FONTS_DIR/" 2>/dev/null || true

echo "Installing Lilex font..."
LILEX_URL="https://github.com/mishamyrt/Lilex/releases/download/2.621/Lilex.zip"
LILEX_ZIP="$REPOS_DIR/Lilex.zip"
curl -fLo "$LILEX_ZIP" "$LILEX_URL"
unzip -o "$LILEX_ZIP" -d "$FONTS_DIR/Lilex" "*.ttf" "*.otf" 2>/dev/null || true
rm "$LILEX_ZIP"

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

echo "Installing Powerline fonts..."
POWERLINE_DIR="$REPOS_DIR/powerline-fonts"
if [ ! -d "$POWERLINE_DIR" ]; then
    git clone https://github.com/powerline/fonts.git "$POWERLINE_DIR" --depth=1
fi
cd "$POWERLINE_DIR"
./install.sh
cd -

echo "Installing system font packages..."
if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm \
        noto-fonts noto-fonts-emoji \
        ttf-roboto adobe-source-code-pro-fonts \
        terminus-font ttf-fira-code ttf-firacode-nerd ttf-jetbrains-mono-nerd \
        ttf-nerd-fonts-symbols-mono \
        || true
    aur_helper=""
    command -v paru >/dev/null 2>&1 && aur_helper=paru
    [ -z "$aur_helper" ] && command -v yay >/dev/null 2>&1 && aur_helper=yay
    if [ -n "$aur_helper" ]; then
        "$aur_helper" -S --needed --noconfirm \
            ttf-harmonyos-sans ttf-ms-fonts || true
    else
        echo "NOTE: no AUR helper (paru/yay) — skipping ttf-harmonyos-sans, ttf-ms-fonts"
    fi
elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y \
        fonts-noto fonts-noto-color-emoji fonts-firacode fonts-roboto \
        fonts-terminus fonts-hack || true
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y \
        google-noto-sans-fonts google-noto-emoji-fonts fira-code-fonts \
        google-roboto-fonts terminus-fonts adobe-source-code-pro-fonts || true
fi

echo "Refreshing font cache..."
fc-cache -fv

echo "Font installation complete!"
echo "Installed fonts:"
fc-list | grep -iE "lilex|sf pro|firacode nerd|jetbrains.*nerd|noto sans|powerline" | cut -d: -f2 | sort -u
