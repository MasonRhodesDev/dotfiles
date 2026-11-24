{
  name = "zoxide";
  description = "Frecent-directory cd.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.zoxide ];
    home.file.".bashrc.d/zoxide.bashrc".source = ./zoxide.bashrc;
  };
}
