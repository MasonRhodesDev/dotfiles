let
  linuxSuspendMinutes = {
    laptop = 5;
    desktop = 30;
    server = null;
  };
  darwinPower = {
    laptop.sleep = { computer = 5; display = 3; };
    desktop.sleep.computer = 30;
    server = { sleep.computer = "never"; restartAfterPowerFailure = true; };
  };
in
{
  name = "Suspend";
  description = "Sleep after idle, timed by form: a laptop after 5 minutes, a desktop after 30, a server never. Linux: hypr-DE's hypridle override, only with a graphical session, and with Steam a hold on suspend while gamemode is active or Steam is downloading. darwin: power.sleep, with display sleep at 3 minutes on a laptop, and a server that never sleeps and starts again after a power failure.";
  platforms = [ "linux" "darwin" ];

  linux.home = { lib, machine, ... }:
    let minutes = linuxSuspendMinutes.${machine.traits.form}; in
    lib.mkIf (minutes != null && !machine.traits.headless) ({
      xdg.configFile."hypr-de/hypridle.conf".text = ''
        $suspend_timeout = ${toString (minutes * 60)}
      '';
    } // lib.optionalAttrs (lib.elem "steam" machine.enabled) {
      home.file.".local/bin/hold-suspend" = { source = ./hold-suspend; executable = true; };
      systemd.user.services.hold-suspend = {
        Unit = {
          Description = "Hold off suspend while gamemode is active or Steam is downloading";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "%h/.local/bin/hold-suspend";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    });

  darwin.system = { machine, ... }: {
    power = darwinPower.${machine.traits.form};
  };

  checks = { pkgs, ... }: {
    hold-suspend = pkgs.runCommand "hold-suspend" { nativeBuildInputs = [ pkgs.bash pkgs.findutils pkgs.gnugrep pkgs.coreutils ]; } ''
      mkdir bin
      cat > bin/systemd-inhibit <<'STUB'
      #!/bin/sh
      echo "inhibit $*" > "$OUT"
      kill "$PPID"
      STUB
      cat > bin/sleep <<'STUB'
      #!/bin/sh
      echo idle > "$OUT"
      kill "$PPID"
      STUB
      chmod +x bin/*
      export PATH=$PWD/bin:$PATH STEAM_CONTENT_LOG=$PWD/content_log.txt OUT=$PWD/out
      gamemode() { printf '#!/bin/sh\necho "gamemode is %s"\n' "$1" > bin/gamemoded; chmod +x bin/gamemoded; }
      rate() { printf '[2026-11-16 09:44:36] Current download rate: %s Mbps\n' "$@" > "$STEAM_CONTENT_LOG"; }
      run() { rm -f "$OUT"; bash ${./hold-suspend} || true; cat "$OUT"; }
      failures=0
      expect() { local got; got=$(run); case $got in $2) ;; *) echo "FAIL $1: got '$got'"; failures=$((failures + 1)) ;; esac; }

      gamemode active
      expect "gamemode active holds suspend" "inhibit --what=sleep --mode=block --who=hold-suspend --why=gamemode is active sleep 60"
      gamemode inactive
      rate 591.399
      expect "a fresh nonzero download rate holds suspend" "inhibit --what=sleep --mode=block --who=hold-suspend --why=Steam is downloading sleep 60"
      rate 591.399 0.000
      expect "a download that ended does not hold suspend" "idle"
      rate 591.399
      touch -d '-10 minutes' "$STEAM_CONTENT_LOG"
      expect "a stale log does not hold suspend" "idle"
      rm -f bin/gamemoded "$STEAM_CONTENT_LOG"
      expect "no gamemode and no Steam log do not hold suspend" "idle"

      [ "$failures" = 0 ]
      touch $out
    '';
  };
}
