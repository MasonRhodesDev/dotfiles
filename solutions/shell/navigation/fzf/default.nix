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
}
