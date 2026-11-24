let
  height = 32;
  colors = { bar = "0xff19120c"; text = "0xffefe0d6"; active = "0xffffb77a"; };
  workspaces = map toString (builtins.genList (i: i + 1) 10) ++ [ "S" ];
in
{
  name = "Status bar";
  description = "Linux: waybar with workspace buttons. darwin: SketchyBar in place of the hidden menu bar, with AeroSpace workspaces, the front app, a keep-awake toggle, volume, battery and clock.";
  platforms = [ "linux" "darwin" ];
  requires = [ "window-manager" ];

  linux.root.packages = {
    arch = [ "waybar" "waybar-workspace-buttons" ];
    fedora = [ "waybar" "waybar-workspace-buttons" ];
  };

  darwin.home = { config, lib, pkgs, osConfig, ... }:
    let
      aerospace = "${osConfig.homebrew.prefix}/bin/aerospace";
      sketchybar = "${config.programs.sketchybar.finalPackage}/bin/sketchybar";

      workspace = pkgs.writeShellScript "sketchybar-workspace" ''
        sid=$1
        focused=''${FOCUSED_WORKSPACE:-$(${aerospace} list-workspaces --focused)}
        if [ "$sid" = "$focused" ]; then
          ${sketchybar} --set "$NAME" drawing=on background.drawing=on label.color=${colors.bar}
        elif [ -n "$(${aerospace} list-windows --workspace "$sid" 2>/dev/null)" ]; then
          ${sketchybar} --set "$NAME" drawing=on background.drawing=off label.color=${colors.text}
        else
          ${sketchybar} --set "$NAME" drawing=off
        fi
      '';
      frontApp = pkgs.writeShellScript "sketchybar-front-app" ''
        case $SENDER in
          front_app_switched) ${sketchybar} --set "$NAME" label="$INFO" ;;
          mouse.clicked)
            ${sketchybar} --bar hidden=on
            (sleep 8; ${sketchybar} --bar hidden=off) > /dev/null 2>&1 &
            ;;
        esac
      '';
      volume = pkgs.writeShellScript "sketchybar-volume" ''
        [ "$SENDER" = volume_change ] && ${sketchybar} --set "$NAME" label="vol $INFO%"
      '';
      battery = pkgs.writeShellScript "sketchybar-battery" ''
        pct=$(pmset -g batt | grep -Eo '[0-9]+%' | head -1)
        [ -n "$pct" ] || exit 0
        if pmset -g batt | grep -q 'AC Power'; then state=ac; else state=bat; fi
        ${sketchybar} --set "$NAME" label="$state $pct"
      '';
      caffeine = pkgs.writeShellScript "sketchybar-caffeine" ''
        awake() { /usr/bin/pgrep -fxq "/usr/bin/caffeinate -di"; }
        if [ "$SENDER" = mouse.clicked ]; then
          if awake; then /usr/bin/pkill -fx "/usr/bin/caffeinate -di"
          else /usr/bin/nohup /usr/bin/caffeinate -di > /dev/null 2>&1 &
          fi
          sleep 0.2
        fi
        if awake; then
          ${sketchybar} --set "$NAME" label="☕ on" background.drawing=on label.color=${colors.bar}
        else
          ${sketchybar} --set "$NAME" label="☕ off" background.drawing=off label.color=${colors.text}
        fi
      '';
    in
    {
      programs.sketchybar = {
        enable = true;
        config = ''
          sketchybar --bar position=top height=${toString height} color=${colors.bar} shadow=off sticky=on topmost=on

          sketchybar --default \
            icon.drawing=off \
            label.font="SF Pro:Semibold:13.0" label.color=${colors.text} \
            padding_left=4 padding_right=4 label.padding_left=8 label.padding_right=8

          sketchybar --add event aerospace_workspace_change
          ${lib.concatMapStrings (sid: ''
            sketchybar --add item space.${sid} left \
              --subscribe space.${sid} aerospace_workspace_change \
              --set space.${sid} label=${sid} \
                background.color=${colors.active} background.corner_radius=6 background.height=22 background.drawing=off \
                click_script="${aerospace} workspace ${sid}" \
                script="${workspace} ${sid}"
          '') workspaces}
          sketchybar --add item front_app left \
            --subscribe front_app front_app_switched mouse.clicked \
            --set front_app script="${frontApp}"

          sketchybar --add item clock right --set clock update_freq=30 script='sketchybar --set $NAME label="$(date "+%I:%M %p")"'
          sketchybar --add item battery right --subscribe battery power_source_change system_woke --set battery update_freq=120 script="${battery}"
          sketchybar --add item volume right --subscribe volume volume_change --set volume script="${volume}"
          sketchybar --add item caffeine right --subscribe caffeine mouse.clicked system_woke \
            --set caffeine update_freq=60 script="${caffeine}" \
              background.color=${colors.active} background.corner_radius=6 background.height=22 background.drawing=off

          sketchybar --update
        '';
      };

      home.activation.sketchybarReload = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -v DRY_RUN ]]; then ${sketchybar} --reload 2>/dev/null || true; fi
      '';

      programs.aerospace.settings = {
        exec-on-workspace-change = [
          "/bin/bash"
          "-c"
          "${sketchybar} --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
        ];
        gaps.outer.top = height + 5;
      };
    };

  darwin.system.system.defaults.NSGlobalDomain._HIHideMenuBar = true;
}
