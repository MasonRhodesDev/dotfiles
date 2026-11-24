{
  name = "gitleaks";
  description = "Secret scanner.";
  platforms = [ "linux" "darwin" ];
  requires = [ "git" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.gitleaks ];
  };
}
