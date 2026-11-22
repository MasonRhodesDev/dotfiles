{
  name = "gitleaks";
  description = "Secret scanner. Hook wiring moves to the flake devShell.";
  platforms = [ "linux" "darwin" ];
  requires = [ "git" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.gitleaks ];
  };
}
