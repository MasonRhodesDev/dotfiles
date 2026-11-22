{
  name = "direnv";
  description = "Load .envrc on cd (nix-shell, per-project env).";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.direnv ];
    home.file.".bashrc.d/direnv.bashrc".source = ./direnv.bashrc;
  };
}
