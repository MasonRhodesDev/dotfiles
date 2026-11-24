{
  name = "WirePlumber";
  description = "Soft-mixer policy: software volume on the outputs whose hardware mixer is too coarse.";
  platforms = [ "linux" ];

  linux.home = { lib, machine, ... }: {
    xdg.configFile."wireplumber/wireplumber.conf.d/51-soft-mixer.conf" = lib.mkIf (machine.private ? softMixerNodes) {
      text = import ./soft-mixer.nix machine.private.softMixerNodes;
    };
  };

  linux.root.packages = {
    arch = [ "wireplumber" ];
    fedora = [ "wireplumber" ];
  };
}
