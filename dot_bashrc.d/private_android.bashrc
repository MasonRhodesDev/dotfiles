# Android — env vars + PATH live in ~/.config/environment.d/android.conf
# so every shell/GUI inherits them from the systemd user session. This file
# keeps only the shell-specific `ae` wrapper.

# Wrapper for ae to force XCB (emulator lacks Wayland support)
ae() {
    QT_QPA_PLATFORM=xcb command ae "$@"
}
