function ae --wraps=ae --description "Android Emulator Launcher"
    QT_QPA_PLATFORM=xcb command ae $argv
end
