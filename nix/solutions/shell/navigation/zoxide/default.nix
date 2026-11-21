{
  name = "zoxide";
  description = "Frecent-directory cd.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.zoxide ];
    home.file.".bashrc.d/zoxide.bashrc".source = ./zoxide.bashrc;
  };

  inventory = {
    files = [ ".bashrc.d/zoxide.bashrc" ];
    scripts = [
      {
        id = "06-install-shell-tools:zoxide";
        root = false;
      }
    ];
    packages = {
      linux = [ "zoxide" ];
      darwin = [ "zoxide" ];
    };
  };
}
