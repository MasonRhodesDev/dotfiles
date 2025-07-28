LEFT_MONITOR="HDMI-A-0" # secondary; 1920x1080; centered vertically with middle monitor
MIDDLE_MONITOR="DisplayPort-1" # primary; 3440x1440; refresh rate 143.97hz;
RIGHT_MONITOR="DisplayPort-2" # tertiary; 3840x2160; centered vertically with middle monitor; scaled 125%; rotated right


xrandr \
    --output $MIDDLE_MONITOR --auto --mode 3440x1440 --scale 1x1 --pos 0x0 --rotate normal \
    --output $LEFT_MONITOR --auto --mode 1920x1080 --scale 1x1 --pos -1920x135 --rotate normal \
    --output $RIGHT_MONITOR --auto --mode 3840x2160 --scale 1x1 --pos 3440x0 --rotate right