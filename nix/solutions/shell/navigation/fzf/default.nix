{
  name = "fzf";
  description = "Ctrl-T file picker and Alt-C cd.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.fzf ];
    home.file.".bashrc.d/10-fzf.bashrc".text =
      builtins.replaceStrings [ "@fzf@" ] [ "${pkgs.fzf}/share/fzf" ] (builtins.readFile ./10-fzf.bashrc);
  };

  inventory = {
    files = [ ".bashrc.d/10-fzf.bashrc" ];
    scripts = [
      {
        id = "06-install-shell-tools:fzf";
        root = false;
      }
    ];
    packages = {
      linux = [ "fzf" ];
      darwin = [ "fzf" ];
    };
  };
}
