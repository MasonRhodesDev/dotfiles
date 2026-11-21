{
  name = "ZSA keyboards";
  description = "udev rules for Moonlander/Ergodox/Voyager flashing.";
  platforms = [ "linux" ];
  when.hardware = "zsa-keyboard";

  linux.root.files."/etc/udev/rules.d/50-zsa.rules" = {
    text = builtins.readFile ./50-zsa.rules;
    reload = ''
      udevadm control --reload
      for device in /sys/bus/usb/devices/*; do
        if [ "$(cat "$device/idVendor" 2>/dev/null)" = 3297 ]; then
          udevadm trigger --parent-match="$device"
        fi
      done
    '';
  };

  inventory = {
    scripts = [
      {
        id = "53-system-session-tweaks:zsa-udev";
        root = true;
      }
    ];
  };
}
