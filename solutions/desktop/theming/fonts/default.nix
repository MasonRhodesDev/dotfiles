{
  name = "Fonts";
  description = "Code and UI fonts. SF Pro is native on darwin.";
  platforms = [ "linux" "darwin" ];

  linux.home = { pkgs, ... }: {
    fonts.fontconfig.enable = true;
    home.packages = [
      pkgs.lilex
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.symbols-only
    ];
    xdg.configFile."fontconfig/fonts.conf".source = ./fonts.conf;
  };

  linux.root.packages = {
    arch = [
      "noto-fonts"
      "noto-fonts-emoji"
      "ttf-roboto"
      "adobe-source-code-pro-fonts"
      "terminus-font"
      "ttf-fira-code"
      "ttf-firacode-nerd"
      "ttf-jetbrains-mono-nerd"
      "ttf-nerd-fonts-symbols-mono"
    ];
    fedora = [
      "google-noto-sans-fonts"
      "google-noto-emoji-fonts"
      "fira-code-fonts"
      "google-roboto-fonts"
      "terminus-fonts"
      "adobe-source-code-pro-fonts"
    ];
  };

  darwin.system = { pkgs, ... }: {
    fonts.packages = [
      pkgs.lilex
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.symbols-only
    ];
  };
}
