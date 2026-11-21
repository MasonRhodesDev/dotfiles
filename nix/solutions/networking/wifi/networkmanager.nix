{
  name = "NetworkManager";
  description = "NetworkManager with Wi-Fi power save off for call latency.";
  platforms = [ "linux" ];

  linux.root = {
    packages = {
      arch = [ "networkmanager" ];
      fedora = [ "NetworkManager" ];
    };
    files."/etc/NetworkManager/conf.d/wifi-powersave-off.conf" = {
      text = ''
        [connection]
        wifi.powersave = 2
      '';
      reload = ''
        if command -v nmcli > /dev/null && nmcli -t general status > /dev/null 2>&1; then
          nmcli general reload conf
        fi
      '';
    };
  };

  inventory = {
    scripts = [
      {
        id = "50-nm-wifi-powersave:generic";
        root = true;
      }
    ];
    packages = {
      linux = [ "NetworkManager" ];
    };
  };
}
