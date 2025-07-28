#!/bin/bash

# Test script to isolate what causes Cursor to crash during theme switching

echo "🔬 Testing individual components that might crash Cursor..."
echo "Run this while Cursor is open and observe which step causes the crash."
echo

read -p "Press Enter to test gsettings GTK theme change..."
echo "1. Testing gsettings gtk-theme change..."
gsettings set org.gnome.desktop.interface gtk-theme "Breeze"
sleep 2
echo "   ✓ GTK theme change completed"

read -p "Press Enter to test gsettings color-scheme change..."
echo "2. Testing gsettings color-scheme change..."
gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
sleep 2
echo "   ✓ Color scheme change completed"

read -p "Press Enter to test dbus environment update..."
echo "3. Testing dbus-update-activation-environment..."
export GTK_THEME="Breeze"
export QT_STYLE_OVERRIDE="Breeze"
dbus-update-activation-environment --systemd GTK_THEME QT_STYLE_OVERRIDE 2>/dev/null || true
sleep 2
echo "   ✓ DBus environment update completed"

read -p "Press Enter to test hyprctl setenv commands..."
echo "4. Testing hyprctl setenv..."
hyprctl setenv GTK_THEME "$GTK_THEME" 2>/dev/null || true
hyprctl setenv QT_STYLE_OVERRIDE "$QT_STYLE_OVERRIDE" 2>/dev/null || true
sleep 2
echo "   ✓ Hyprctl setenv completed"

read -p "Press Enter to test portal gdbus call..."
echo "5. Testing desktop portal call..."
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme >/dev/null 2>&1 || true
sleep 2
echo "   ✓ Portal call completed"

read -p "Press Enter to test matugen generation..."
echo "6. Testing matugen color generation..."
WALLPAPER_PATH=$(grep "env = WALLPAPER_PATH" "$HOME/.config/hypr/configs/env.conf" | cut -d',' -f2)
if [[ -n "$WALLPAPER_PATH" && -f "$WALLPAPER_PATH" ]]; then
    matugen image "$WALLPAPER_PATH" -m light >/dev/null 2>&1
    /home/mason/scripts/generate-theme-configs.py "$WALLPAPER_PATH" light >/dev/null 2>&1
fi
sleep 2
echo "   ✓ Matugen generation completed"

echo
echo "🏁 Test completed. Which step caused Cursor to crash?"
echo "1. gsettings gtk-theme"
echo "2. gsettings color-scheme" 
echo "3. dbus-update-activation-environment"
echo "4. hyprctl setenv"
echo "5. gdbus portal call"
echo "6. matugen generation"
echo
echo "If Cursor didn't crash, the issue might be in the combination of steps"
echo "or the timing/frequency of changes."