# Android SDK
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx ANDROID_AVD_HOME "$HOME/.var/app/com.google.AndroidStudio/config/.android/avd"
set -gx ANDROID_EMULATOR_USE_SYSTEM_LIBS 1
if test -d $ANDROID_HOME
    for p in $ANDROID_HOME/emulator $ANDROID_HOME/platform-tools
        if not string match -q "*$p*" $PATH
            set -gx PATH $PATH $p
        end
    end
end

# Wrapper for ae to force XCB (emulator lacks Wayland support)
function ae --wraps=ae --description "Android Emulator Launcher"
    QT_QPA_PLATFORM=xcb command ae $argv
end
