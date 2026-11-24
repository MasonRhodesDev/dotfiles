{
  name = "ble.sh";
  description = "Line editor with autosuggestions and syntax highlighting.";
  platforms = [ "linux" "darwin" ];
  requires = [ "bash" ];

  home = { pkgs, ... }: {
    home.file.".local/share/blesh".source = "${pkgs.blesh}/share/blesh";
    home.file.".blerc".source = ./blerc;
  };
}
