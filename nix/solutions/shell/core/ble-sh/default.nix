{
  name = "ble.sh";
  description = "Line editor with autosuggestions and syntax highlighting.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.file.".local/share/blesh".source = "${pkgs.blesh}/share/blesh";
    home.file.".blerc".source = ./blerc;
  };

  inventory = {
    files = [ ".blerc" ".local/share/blesh" ];
    scripts = [
      {
        id = "06-install-shell-tools:ble-sh";
        root = false;
      }
    ];
    packages = {
      linux = [ "blesh" ];
      darwin = [ "blesh" ];
    };
  };
}
