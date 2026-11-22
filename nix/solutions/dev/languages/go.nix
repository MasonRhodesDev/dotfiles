{
  name = "Go";
  description = "Go toolchain.";
  platforms = [ "linux" "darwin" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.go ];
  };
}
