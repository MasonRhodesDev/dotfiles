#!/bin/bash
selection=$(hyprlauncher -o "Logout,Reboot,Shutdown,Suspend")

case "$selection" in
    Logout)   hyprshutdown ;;
    Reboot)   hyprshutdown -p 'systemctl reboot' ;;
    Shutdown) hyprshutdown -p 'systemctl poweroff -i' ;;
    Suspend)  systemctl suspend ;;
esac
