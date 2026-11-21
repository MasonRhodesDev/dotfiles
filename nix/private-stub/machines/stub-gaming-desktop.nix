{
  system = "x86_64-linux";
  traits = { headless = false; form = "desktop"; profile = "personal"; secrets = "infisical"; uses = [ "dev" "gaming" ]; hardware = [ "swiftpoint-mouse" "zsa-keyboard" "razer" "xbox-controller" "3d-printer" ]; };
  user = { name = "alex"; home = "/home/alex"; };
  private.xwaylandPrimary = "EXAMPLE-MONITOR";
  private.softMixerNodes = [ "~alsa_output.usb-Example_Headset.*" ];
  private.ssh."example-nas" = { HostName = "nas.example.invalid"; User = "games"; IdentityFile = "~/.ssh/games"; IdentitiesOnly = true; };
}
