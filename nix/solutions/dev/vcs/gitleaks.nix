{
  name = "gitleaks";
  description = "Secret scanner. Hook wiring moves to the flake devShell.";
  platforms = [ "linux" "darwin" ];
  requires = [ "git" ];

  home = { pkgs, ... }: {
    home.packages = [ pkgs.gitleaks ];
  };

  inventory = {
    scripts = [
      {
        id = "40-setup-git-hooks";
        root = false;
        note = "gitleaks only; core.hooksPath is per clone";
      }
    ];
    packages = {
      linux = [ "gitleaks" ];
      darwin = [ "gitleaks" ];
    };
  };
}
