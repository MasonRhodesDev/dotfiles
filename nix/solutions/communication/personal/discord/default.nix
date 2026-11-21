{
  name = "Discord";
  description = "Discord. Linux: Wayland flags, started with the session. darwin: the cask.";
  platforms = [ "linux" "darwin" ];
  requires = [ "window-manager" ];

  linux.home = { lib, ... }: {
    xdg.configFile."discord-flags.conf".source = ./discord-flags.conf;
    dotfiles.fragments."hypr/autostart" = lib.mkAfter "    hl.exec_cmd(\"uwsm app -- discord\")\n";
    dotfiles.fragments."hypr/local.lua" = ''
      hl.window_rule({ name = "discord-special", match = { class = "^(discord)$" }, workspace = "special:magic silent" })
    '';
  };

  linux.root.packages.arch = [ "discord" ];

  darwin.system.homebrew.casks = [ "discord" ];

  inventory = {
    starts = {
      linux = [ "hypr-autostart: discord" ];
    };
    files = [ ".config/discord-flags.conf" ".config/hypr/local.lua#autostart-discord" ".config/hypr/local.lua#discord" ];
    packages = {
      linux = [ "discord" ];
      darwin = [ "discord (cask)" ];
    };
  };
}
