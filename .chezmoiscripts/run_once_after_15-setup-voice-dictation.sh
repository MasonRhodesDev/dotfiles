#!/bin/bash
set -e

echo "Setting up voice dictation with nerd-dictation..."

if command -v dnf > /dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
    PYTHON_PIP="pip"
    echo "Detected Fedora Linux"
elif command -v pacman > /dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
    PYTHON_PIP="pip"
    echo "Detected Arch Linux"
else
    echo "Error: Unsupported system. This script requires Fedora or Arch Linux."
    exit 1
fi

echo "Installing Python vosk package..."
if ! python3 -c "import vosk" 2>/dev/null; then
    $PYTHON_PIP install --user vosk
    echo "Vosk installed successfully"
else
    echo "Vosk already installed"
fi

echo "Installing wtype for Wayland input simulation..."
if ! command -v wtype > /dev/null 2>&1; then
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf install -y wtype
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm wtype
    fi
    echo "wtype installed successfully"
else
    echo "wtype already installed"
fi

echo "Cloning nerd-dictation repository..."
if [ ! -d "$HOME/scripts/nerd-dictation" ]; then
    mkdir -p "$HOME/scripts"
    git clone https://github.com/ideasman42/nerd-dictation.git "$HOME/scripts/nerd-dictation"
    echo "nerd-dictation cloned successfully"
else
    echo "nerd-dictation already exists"
fi

echo "Downloading Vosk English model..."
if [ ! -d "$HOME/.config/nerd-dictation/model" ]; then
    mkdir -p "$HOME/.config/nerd-dictation"
    cd "$HOME/.config/nerd-dictation"
    
    wget -q https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
    unzip -q vosk-model-small-en-us-0.15.zip
    mv vosk-model-small-en-us-0.15 model
    rm vosk-model-small-en-us-0.15.zip
    
    echo "Vosk model downloaded successfully"
else
    echo "Vosk model already exists"
fi

echo "Creating dictation control wrapper script..."
cat > "$HOME/scripts/dictation-control" << 'EOF'
#!/bin/bash

NERD_DICTATION="$HOME/scripts/nerd-dictation/nerd-dictation"
VOSK_MODEL="$HOME/.config/nerd-dictation/model"
INPUT_TOOL="WTYPE"

case "$1" in
    start)
        if pgrep -f "nerd-dictation begin" > /dev/null; then
            notify-send -u normal "Voice Dictation" "Already running"
        else
            notify-send -u normal "Voice Dictation" "Starting... Speak now" -i microphone-sensitivity-high
            $NERD_DICTATION begin --vosk-model-dir="$VOSK_MODEL" --simulate-input-tool="$INPUT_TOOL" &
        fi
        ;;
    stop)
        if pgrep -f "nerd-dictation begin" > /dev/null; then
            $NERD_DICTATION end
            notify-send -u normal "Voice Dictation" "Stopped" -i microphone-sensitivity-muted
        else
            notify-send -u normal "Voice Dictation" "Not running"
        fi
        ;;
    toggle)
        if pgrep -f "nerd-dictation begin" > /dev/null; then
            $NERD_DICTATION end
            notify-send -u normal "Voice Dictation" "Stopped" -i microphone-sensitivity-muted
        else
            notify-send -u normal "Voice Dictation" "Starting... Speak now" -i microphone-sensitivity-high
            $NERD_DICTATION begin --vosk-model-dir="$VOSK_MODEL" --simulate-input-tool="$INPUT_TOOL" &
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|toggle}"
        exit 1
        ;;
esac
EOF

chmod +x "$HOME/scripts/dictation-control"
echo "Dictation control script created successfully"

echo ""
echo "Voice dictation setup complete!"
echo "Usage: Press Meh+V (Ctrl+Alt+Shift+V) to toggle dictation"
echo "The dictation will type text in real-time as you speak"
