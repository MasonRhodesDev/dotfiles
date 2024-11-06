UltraWideSN=HSRTS63
# LgSN=103NDWEG3153
Dell4KSN=6VSGM43

# function to change input source on ddc/ci monitor by serial number

CURRENT_INPUT=$(ddcutil --sn $UltraWideSN getvcp 0x60 -t --skip-ddc-checks | awk -F' ' '{print $4}')

# if current input is HDMI1, switch to Windows config
if [[ "$CURRENT_INPUT" -eq "x11" ]]; then
  echo "Switching to Windows"
  sudo ddcutil --sn $UltraWideSN setvcp 0x60 0x0f > /dev/null
  sudo ddcutil --sn $Dell4KSN setvcp 0x60 0x0f > /dev/null
  # sudo ddcutil --sn $LgSN setvcp 0x60 0x04 > /dev/null &
  wait
else
  echo "Switching to Linux"
  sudo ddcutil --sn $UltraWideSN setvcp 0x60 0x11 > /dev/null
  sudo ddcutil --sn $Dell4KSN setvcp 0x60 0x11 > /dev/null
  # sudo ddcutil --sn $LgSN setvcp 0x60 0x03 > /dev/null &
  wait
fi
