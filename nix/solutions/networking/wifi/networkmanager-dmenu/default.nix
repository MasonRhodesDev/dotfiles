{
  name = "networkmanager-dmenu";
  description = "Wi-Fi picker in the launcher.";
  platforms = [ "linux" ];
  requires = [ "networkmanager" ];

  linux.home = { ... }: {
    xdg.configFile."networkmanager-dmenu/config.ini".source = ./config.ini;
    home.file.".local/bin/networkmanager-dmenu" = { source = ./networkmanager-dmenu; executable = true; };
  };

  inventory = {
    files = [ ".config/networkmanager-dmenu/config.ini" ".local/bin/networkmanager-dmenu" ];
  };
}
