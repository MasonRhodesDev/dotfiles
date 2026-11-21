{
  name = "Atuin";
  description = "Ctrl-R history search with its own database.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.atuin ];
    dotfiles.fragments."bash/completions" = "gen atuin     atuin gen-completions --shell bash\n";
    home.file.".config/atuin/config.toml".source = ./config.toml;
    home.file.".bashrc.d/atuin.bashrc".source = ./atuin.bashrc;
  };

  inventory = {
    files = [ ".config/atuin/config.toml" ".bashrc.d/atuin.bashrc" ];
    scripts = [
      {
        id = "06-install-shell-tools:atuin";
        root = false;
      }
    ];
    packages = {
      linux = [ "atuin" ];
      darwin = [ "atuin" ];
    };
  };
}
