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

echo "Installing Python packages (vosk, PyAudio)..."
if ! python3 -c "import vosk" 2>/dev/null; then
    $PYTHON_PIP install --user vosk
    echo "Vosk installed successfully"
else
    echo "Vosk already installed"
fi

if ! python3 -c "import pyaudio" 2>/dev/null; then
    if [ "$PACKAGE_MANAGER" = "dnf" ]; then
        sudo dnf install -y portaudio-devel python3-devel
    elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
        sudo pacman -S --noconfirm portaudio python-pyaudio
    fi
    $PYTHON_PIP install --user PyAudio
    echo "PyAudio installed successfully"
else
    echo "PyAudio already installed"
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

echo "Creating dictation GUI script..."
cat > "$HOME/scripts/dictation-gui" << 'EOF'
#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Gdk, GLib, GObject
import subprocess
import threading
import struct
import math
import sys
import os

try:
    import pyaudio
    PYAUDIO_AVAILABLE = True
except ImportError:
    PYAUDIO_AVAILABLE = False

class DictationWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        
        self.audio_level = 0.0
        self.bars = []
        self.monitoring = False
        
        self.set_title("Voice Dictation")
        self.set_default_size(300, 60)
        self.set_decorated(False)
        self.set_resizable(False)
        
        self.set_can_focus(False)
        
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(b"""
            window {
                background-color: rgba(30, 30, 46, 0.95);
                border-radius: 30px;
            }
            .pill-box {
                padding: 15px 25px;
            }
            .soundwave-bar {
                background-color: rgba(137, 180, 250, 0.8);
                border-radius: 2px;
                min-width: 3px;
                margin: 0 2px;
            }
        """)
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        box.add_css_class("pill-box")
        box.set_halign(Gtk.Align.CENTER)
        box.set_valign(Gtk.Align.CENTER)
        
        for i in range(12):
            bar = Gtk.Box()
            bar.add_css_class("soundwave-bar")
            bar.set_size_request(3, 10)
            box.append(bar)
            self.bars.append(bar)
        
        self.set_child(box)
        
        self.position_window()
        
        GLib.timeout_add(50, self.animate_soundwave)
        
        threading.Thread(target=self.monitor_audio, daemon=True).start()
    
    def position_window(self):
        display = Gdk.Display.get_default()
        monitor = display.get_monitors()[0]
        geometry = monitor.get_geometry()
        
        width = 300
        height = 60
        x = (geometry.width - width) // 2
        y = geometry.height - height - 80
        
        self.present()
    
    def animate_soundwave(self):
        if not self.monitoring:
            return False
        
        import random
        base_level = self.audio_level
        
        for i, bar in enumerate(self.bars):
            offset = abs(i - 6) / 6.0
            noise = random.uniform(0.7, 1.3)
            level = base_level * (1.0 - offset * 0.5) * noise
            
            min_height = 5
            max_height = 35
            height = int(min_height + level * (max_height - min_height))
            
            bar.set_size_request(3, height)
        
        return True
    
    def monitor_audio(self):
        self.monitoring = True
        
        if PYAUDIO_AVAILABLE:
            self.monitor_audio_pyaudio()
        else:
            self.monitor_audio_fallback()
    
    def monitor_audio_pyaudio(self):
        try:
            p = pyaudio.PyAudio()
            
            stream = p.open(
                format=pyaudio.paInt16,
                channels=1,
                rate=44100,
                input=True,
                frames_per_buffer=1024
            )
            
            while self.monitoring:
                try:
                    data = stream.read(1024, exception_on_overflow=False)
                    
                    audio_data = struct.unpack(str(1024) + 'h', data)
                    
                    peak = max(abs(x) for x in audio_data)
                    
                    normalized = peak / 32768.0
                    
                    self.audio_level = min(1.0, normalized * 2.0)
                    
                except Exception as e:
                    pass
            
            stream.stop_stream()
            stream.close()
            p.terminate()
            
        except Exception as e:
            print(f"PyAudio monitoring error: {e}", file=sys.stderr)
            self.monitor_audio_fallback()
    
    def monitor_audio_fallback(self):
        try:
            cmd = ['pactl', 'subscribe']
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            while self.monitoring:
                line = process.stdout.readline()
                if not line:
                    break
                
                if 'source' in line.lower():
                    self.audio_level = min(1.0, self.audio_level + 0.1)
                
                GLib.timeout_add(100, self.decay_audio)
        
        except Exception as e:
            print(f"Audio monitoring error: {e}", file=sys.stderr)
    
    def decay_audio(self):
        self.audio_level = max(0.0, self.audio_level - 0.05)
        return False
    
    def cleanup(self):
        self.monitoring = False

class DictationApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='dev.mason.dictation')
        self.window = None
    
    def do_activate(self):
        if not self.window:
            self.window = DictationWindow(self)
        self.window.present()
    
    def do_shutdown(self):
        if self.window:
            self.window.cleanup()
        Gtk.Application.do_shutdown(self)

if __name__ == '__main__':
    app = DictationApp()
    app.run(sys.argv)
EOF

chmod +x "$HOME/scripts/dictation-gui"
echo "Dictation GUI script created successfully"

echo "Creating dictation daemon script..."
cat > "$HOME/scripts/dictation-daemon" << 'EOF'
#!/bin/bash

NERD_DICTATION="$HOME/scripts/nerd-dictation/nerd-dictation"
VOSK_MODEL="$HOME/.config/nerd-dictation/model"
INPUT_TOOL="WTYPE"

if pgrep -f "nerd-dictation begin.*suspend-on-start" > /dev/null; then
    exit 0
fi

$NERD_DICTATION begin \
    --vosk-model-dir="$VOSK_MODEL" \
    --simulate-input-tool="$INPUT_TOOL" \
    --suspend-on-start \
    --continuous &
EOF

chmod +x "$HOME/scripts/dictation-daemon"
echo "Dictation daemon script created successfully"

echo "Creating dictation control wrapper script..."
cat > "$HOME/scripts/dictation-control" << 'EOF'
#!/bin/bash

NERD_DICTATION="$HOME/scripts/nerd-dictation/nerd-dictation"
DICTATION_DAEMON="$HOME/scripts/dictation-daemon"
DICTATION_GUI="$HOME/scripts/dictation-gui"
STATE_FILE="/tmp/dictation-active"

if ! pgrep -f "nerd-dictation begin.*suspend-on-start" > /dev/null; then
    $DICTATION_DAEMON
    sleep 1
fi

case "$1" in
    start)
        if [ -f "$STATE_FILE" ]; then
            exit 0
        fi
        $DICTATION_GUI &
        $NERD_DICTATION resume
        touch "$STATE_FILE"
        ;;
    stop)
        if [ ! -f "$STATE_FILE" ]; then
            exit 0
        fi
        $NERD_DICTATION suspend
        pkill -f "dictation-gui"
        rm -f "$STATE_FILE"
        ;;
    toggle)
        if [ -f "$STATE_FILE" ]; then
            $NERD_DICTATION suspend
            pkill -f "dictation-gui"
            rm -f "$STATE_FILE"
        else
            $DICTATION_GUI &
            $NERD_DICTATION resume
            touch "$STATE_FILE"
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
