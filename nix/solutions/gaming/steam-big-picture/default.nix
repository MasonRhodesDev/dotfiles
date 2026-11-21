{
  name = "Big Picture mode";
  description = "Big Picture focus handling and monitor layout.";
  platforms = [ "linux" ];
  only = "x86_64-linux";
  requires = [ "steam" ];

  linux.home = { lib, pkgs, ... }:
    let python = pkgs.python3.withPackages (p: [ p.evdev ]); in
    {
      xdg.configFile."hypr/bp-common.lua".source = ./bp-common.lua;
      xdg.configFile."hypr/bp-focus.lua".source = ./bp-focus.lua;
      xdg.configFile."hypr/bp-monitors.lua".source = ./bp-monitors.lua;
      xdg.configFile."hypr/scripts/bp-game-focus.py" = { source = ./bp-game-focus.py; executable = true; };

      systemd.user.services.bp-game-focus = {
        Unit = {
          Description = "Big Picture / game focus state machine (Hyprland)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
          ConditionEnvironment = "HYPRLAND_INSTANCE_SIGNATURE";
        };
        Service = {
          Type = "simple";
          ExecStart = "${python}/bin/python3 %h/.config/hypr/scripts/bp-game-focus.py";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      dotfiles.fragments."hypr/local.lua" = lib.mkOrder 1600 ''

        do
            local base = os.getenv("XDG_CONFIG_HOME")
            if not base or base == "" then base = os.getenv("HOME") .. "/.config" end
            for _, name in ipairs({ "bp-focus", "bp-monitors" }) do
                local ok, err = pcall(dofile, base .. "/hypr/" .. name .. ".lua")
                if not ok and not tostring(err):find("No such file", 1, true) then
                    hl.exec_cmd("logger -t hypr-local -- " .. ("'%s: %s'"):format(name, tostring(err):gsub("'", "")))
                end
            end
        end
      '';
    };

  inventory = {
    starts = {
      linux = [ "bp-game-focus.service" ];
    };
    files = [
      ".config/systemd/user/bp-game-focus.service"
      ".config/hypr/bp-common.lua"
      ".config/hypr/bp-focus.lua"
      ".config/hypr/bp-monitors.lua"
      ".config/hypr/scripts/bp-game-focus.py"
      ".config/hypr/local.lua#bp-loader"
    ];
  };
}
