{
  name = "HashiCorp";
  description = "terraform and packer.";
  platforms = [ "linux" "darwin" ];
  when.profile = "work";

  home = { lib, pkgs, machine, ... }:
    let
      unfree = import pkgs.path {
        inherit (pkgs.stdenv.hostPlatform) system;
        config.allowUnfreePackages = [ "terraform" "packer" ];
      };
    in
    {
      dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "stub terraform 'complete -C terraform terraform'\n";
      home.packages = [ unfree.terraform unfree.packer ];
    };

  inventory = {
    packages = {
      linux = [ "terraform" "packer" ];
      darwin = [ "terraform" "packer" ];
    };
  };
}
