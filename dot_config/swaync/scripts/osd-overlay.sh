#!/bin/bash

# Custom centered OSD overlay using wlroots layer shell
# Usage: osd-overlay.sh "icon" "text" "percentage"

icon="$1"
text="$2" 
percentage="$3"

# Kill any existing OSD overlay
pkill -f "osd-overlay-window" 2>/dev/null

# Create temporary overlay window using wlr-layer-shell
cat > /tmp/osd-overlay.html << EOF
<!DOCTYPE html>
<html>
<head>
<style>
body { 
  margin: 0; 
  background: rgba(30, 30, 46, 0.9); 
  color: #cdd6f4; 
  display: flex; 
  flex-direction: column; 
  justify-content: center; 
  align-items: center; 
  width: 300px; 
  height: 300px; 
  border-radius: 20px;
  font-family: 'SF Pro Text', sans-serif;
}
.icon { font-size: 60px; margin-bottom: 20px; }
.text { font-size: 48px; font-weight: 300; }
</style>
</head>
<body>
<div class="icon">$icon</div>
<div class="text">$text</div>
</body>
</html>
EOF

# Display using firefox in kiosk mode for 2 seconds
timeout 2 firefox --kiosk --new-window "file:///tmp/osd-overlay.html" --class="osd-overlay-window" >/dev/null 2>&1 &

# Clean up
sleep 3 && rm -f /tmp/osd-overlay.html &