{
  name = "Bun";
  description = "Bun runtime.";
  platforms = [ "linux" "darwin" ];

  home = { lib, pkgs, machine, ... }: {
    dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen bun       bun completions\n";
    home.packages = [ pkgs.bun ];
  };
}
