{
  name = "T3 device host";
  description = "Lets a T3 Code server open this Mac's iOS Simulators over SSH as a device host. T3 runs its device tools with node and npm from the non-interactive SSH PATH, which starts at ~/.local/bin, and installs those tools into ~/.t3/device itself. The server's key in authorized_keys and the device host entry in T3's settings are set up by hand.";
  platforms = [ "darwin" ];
  requires = [ "xcode" ];

  darwin.home = { pkgs, ... }: {
    home.file.".local/bin/node".source = "${pkgs.nodejs}/bin/node";
    home.file.".local/bin/npm".source = "${pkgs.nodejs}/bin/npm";
  };
}
