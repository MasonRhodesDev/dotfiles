{
  name = "tmux";
  description = "tmux config. Other solutions add lines through the tmux/tmux.conf fragment.";
  platforms = [ "linux" "darwin" ];

  fragments = [ "tmux/tmux.conf" ];

  home = { config, pkgs, ... }: {
    home.packages = [ pkgs.tmux ];
    dotfiles.mutable.".tmux.conf" = {
      strategy = "overwrite";
      text = builtins.readFile ./tmux.conf + (config.dotfiles.fragments."tmux/tmux.conf" or "");
    };
  };

  inventory = {
    files = [ ".tmux.conf" ];
    packages = {
      linux = [ "tmux" ];
      darwin = [ "tmux" ];
    };
  };
}
