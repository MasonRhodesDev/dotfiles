#!/bin/bash
selection=$(printf 'Logout\nReboot\nShutdown\nSuspend' | fuzzel --dmenu --prompt 'Power: ')

case "$selection" in
    Logout)   hyprshutdown ;;
    Reboot)   hyprshutdown -p 'systemctl reboot' ;;
    Shutdown) hyprshutdown -p 'systemctl poweroff -i' ;;
    Suspend)  systemctl suspend ;;
esac
