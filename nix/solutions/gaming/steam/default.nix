{
  name = "Steam";
  description = "Steam, gamemode, launchers, clean shutdown on session end, game window rules and the AMD game env.";
  platforms = [ "linux" ];
  only = "x86_64-linux";
  requires = [ "window-manager" ];
  conflicts = [ "work-identity" ];

  linux.home = { config, lib, ... }: {
    home.file.".local/bin/steam-launch" = { source = ./steam-launch; executable = true; };
    xdg.configFile."hypr/scripts/steam-clean-shutdown.sh" = { source = ./steam-clean-shutdown.sh; executable = true; };

    xdg.configFile."systemd/user/graphical-session.target.wants/steam-clean-shutdown.service".source =
      config.lib.file.mkOutOfStoreSymlink "/usr/lib/systemd/user/steam-clean-shutdown.service";
    xdg.configFile."environment.d/gaming.conf".source = ./gaming.conf;
    home.file.".local/bin/steam-set-launch-options" = { source = ./steam-set-launch-options; executable = true; };

    dotfiles.fragments."hypr/local.lua" = lib.mkAfter ''
      dofile("/usr/share/hypr-de/gaming/game-rules.lua")

      hl.config({ misc = { render_unfocused_fps = 60 } })
      hl.window_rule({ name = "games-render-unfocused", match = { class = "^(steam_app_\\d+)$" }, render_unfocused = true })
      hl.window_rule({ name = "mo2-hidden", match = { class = "^(steam_app_\\d+)$", title = "^(ModOrganizer)$" }, workspace = "special:mo2 silent" })
      hl.window_rule({ name = "cp2077-fullscreen", match = { class = "^(steam_app_1091500)$", title = "^(Cyberpunk 2077.*)$" }, fullscreen = true })
      hl.window_rule({ name = "overwatch-fullscreen", match = { class = "^(steam_app_2357570)$", title = "^(Overwatch)$" }, fullscreen = true })

      hl.config({ xwayland = { force_zero_scaling = true } })
    '';
    dotfiles.fragments."hypr/autostart" = builtins.readFile ./autostart.lua;
  };

  linux.root = {
    distroRepositories.arch = [ "multilib" ];
    packages = {
      arch = [ "steam" "gamemode" "hypr-de-gaming" ];
      fedora = [ "steam" "gamemode" "hypr-de-gaming" ];
    };
  };

  inventory = {
    starts = {
      linux = [ "steam-clean-shutdown.service (hypr-de-gaming)" "hypr-autostart: steam-launch" ];
    };
    files = [
      ".config/systemd/user/graphical-session.target.wants/steam-clean-shutdown.service"
      ".config/hypr/scripts/steam-clean-shutdown.sh"
      ".local/bin/steam-launch"
      ".local/bin/steam-set-launch-options"
      ".config/environment.d/gaming.conf"
      ".config/hypr/local.lua#game-rules"
      ".config/hypr/local.lua#autostart-steam"
    ];
    packages = {
      linux = [ "steam" "gamemode" "hypr-de-gaming" ];
    };
  };
}
