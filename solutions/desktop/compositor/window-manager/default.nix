{
  name = "Tiling window manager";
  description = "Linux: Hyprland with the hypr-DE preset under uwsm, personal layer in hypr/local.lua. darwin: AeroSpace from its signed cask, started by a launchd agent, driven by the keymap through Hammerspoon.";
  platforms = [ "linux" "darwin" ];

  fragments = [ "hypr/local.lua" "hypr/autostart" ];

  linux.home = { config, lib, pkgs, machine, ... }: {
    dotfiles.fragments."hypr/local.lua" = builtins.readFile ./local-core.lua;

    dotfiles.mutable.".config/hypr/local.lua" = {
      strategy = "overwrite";
      text = ''
        ${config.dotfiles.fragments."hypr/local.lua"}
        hl.on("hyprland.start", function()
            local splash = io.open("/usr/bin/desktop-boot-login-splash", "r")
            if splash then
                splash:close()
                hl.exec_cmd("/usr/bin/desktop-boot-login-splash")
            end
        ${config.dotfiles.fragments."hypr/autostart" or ""}
        end)
      '';
    };

    dotfiles.mutable.".config/hypr/power.conf" = { strategy = "overwrite"; source = ./power.conf; };

    xdg.configFile."uwsm/env".text = ''
      export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR}/ssh-agent.socket"
    '';
    home.file.".bashrc.d/05-uwsm-env.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./05-uwsm-env.bashrc; };

    xdg.configFile."xdg-desktop-portal/hyprland-portals.conf".source = ./hyprland-portals.conf;
    xdg.configFile."electron-flags.conf".source = ./electron-flags.conf;

    xdg.configFile."hypr-de/xwayland-primary" = lib.mkIf (machine.private ? xwaylandPrimary) {
      text = "${machine.private.xwaylandPrimary}\n";
    };

    home.packages = [ pkgs.hyprls ];

    home.activation.hyprDeSetup = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      stamp="''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/hypr-de-setup"
      if [[ ! -v DRY_RUN ]] && [[ -x /usr/bin/hypr-de-setup ]]; then
        want=$(sha256sum /usr/bin/hypr-de-setup | cut -d' ' -f1)
        if [[ "$(cat "$stamp" 2>/dev/null)" != "$want" ]]; then
          if /usr/bin/hypr-de-setup; then
            mkdir -p "$(dirname "$stamp")" && echo "$want" > "$stamp"
          else
            warnEcho "hypr-de-setup failed. Run it from the desktop session to enable the bar, notifications and idle units."
          fi
        fi
      fi
    '';
  };

  linux.root = { inputs, lib, ... }:
    let
      pins = import ./pins.nix { inherit lib; };
      approved = "c108ed94f59640d324ffe2a1c29cb64ed4c44913b950a5b4c16f52ccd4a91e67";
    in
    {
      repositories = pins.approved approved (pins.parse (builtins.readFile "${inputs.hypr-de}/get-hypr-de.sh"));
      packages = {
        arch = [ "hypr-de" "hyprstate" "uwsm" ];
        fedora = [ "hypr-de" "hyprstate" "uwsm" ];
      };
    };

  checks = { pkgs, lib, ... }: {
    window-manager-pins = import ./pins-check.nix { inherit lib pkgs; };
  };

  darwin.system = { config, ... }: {
    homebrew.taps = [ "nikitabobko/tap" ];
    homebrew.casks = [ "nikitabobko/tap/aerospace" ];
    dotfiles.permissions.aerospace-accessibility = {
      what = "Accessibility for AeroSpace";
      pane = "accessibility";
      check = "${config.homebrew.prefix}/bin/aerospace list-modes --current";
    };
  };

  darwin.home = { config, lib, osConfig, ... }:
    let aerospace = "${osConfig.homebrew.prefix}/bin/aerospace"; in
    {
      programs.aerospace = {
        enable = true;
        package = null;
        launchd.enable = false;
        settings = {
          config-version = 2;
          enable-normalization-flatten-containers = true;
          enable-normalization-opposite-orientation-for-nested-containers = true;
          default-root-container-layout = "tiles";
          gaps = {
            inner = { horizontal = 10; vertical = 10; };
            outer = { left = 5; right = 5; top = lib.mkDefault 5; bottom = 5; };
          };
          exec = {
            inherit-env-vars = true;
            env-vars.PATH = "${osConfig.homebrew.prefix}/bin:${config.home.profileDirectory}/bin:\${PATH}";
          };
        };
      };

      dotfiles.services.aerospace-wm = {
        description = "AeroSpace tiling window manager";
        command = [ "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ];
        restart = "always";
        launchd.ProcessType = "Interactive";
      };

      home.activation.aerospaceReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -v DRY_RUN ]] && ${aerospace} list-modes --current >/dev/null 2>&1; then
          ${aerospace} reload-config
        fi
      '';
    };
}
