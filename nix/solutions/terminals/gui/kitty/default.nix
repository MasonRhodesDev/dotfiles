let
  linuxConf = builtins.readFile ./kitty.conf;

  darwinConf =
    builtins.replaceStrings
      [
        "shell /usr/bin/bash --login"
        "listen_on            unix:@kitty-{kitty_pid}"
        "map ctrl+v kitten paste_image.py\n"
      ]
      [
        "shell /run/current-system/sw/bin/bash --login"
        "listen_on            unix:/tmp/kitty-{kitty_pid}"
        ""
      ]
      linuxConf
    + ''

      macos_option_as_alt left
    '';

  withFragments = config: base:
    let added = config.dotfiles.fragments."kitty/kitty.conf" or ""; in
    if added == "" then base else "${base}\n${added}";
in
{
  name = "kitty";
  description = "Primary terminal, with remote control on a socket per process. Other solutions add their lines to kitty.conf through the kitty/kitty.conf fragment.";
  platforms = [ "linux" "darwin" ];
  requires = [ "fonts" ];

  fragments = [ "kitty/kitty.conf" ];

  linux.root = {
    packages = {
      arch = [ "kitty" ];
      fedora = [ "kitty" ];
    };
  };

  linux.home = { config, ... }: {
    dotfiles.mutable.".config/kitty/kitty.conf" = { strategy = "overwrite"; text = withFragments config linuxConf; };
    home.file.".config/kitty/paste_image.py".text =
      builtins.replaceStrings [ "@home@" ] [ config.home.homeDirectory ] (builtins.readFile ./paste_image.py);
    home.file."scripts/wezterm-paste-image" = { source = ./wezterm-paste-image; executable = true; };
  };

  darwin.home = { config, pkgs, ... }: {
    home.packages = [ pkgs.kitty ];
    dotfiles.mutable.".config/kitty/kitty.conf" = { strategy = "overwrite"; text = withFragments config darwinConf; };
  };

  inventory = {
    files = [
      ".config/kitty/kitty.conf"
      ".config/kitty/paste_image.py"
      "scripts/wezterm-paste-image"
    ];
    packages = {
      linux = [ "kitty" ];
      darwin = [ "kitty" ];
    };
  };
}
