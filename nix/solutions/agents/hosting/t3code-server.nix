let
  activation = { lib, pkgs, home, session, unit, pgrep, upPath, noSession ? null, up ? true }: ''
    if [[ ! -v DRY_RUN ]] && ${session} > /dev/null 2>&1; then
      t3=${lib.escapeShellArg "${home}/.local/bin/t3"}
      if [ ! -x "$t3" ]; then
        ${pkgs.curl}/bin/curl -fsSL https://t3.codes/install.sh \
          | PATH="${pkgs.curl}/bin:/usr/local/bin:/usr/bin:/bin" /bin/sh \
          || warnEcho "t3code: installing T3 Code failed"
      fi
      ${lib.optionalString up ''if [ -x "$t3" ] && [ ! -e ${lib.escapeShellArg unit} ]; then
        server=0
        ${pgrep} -U "$UID" -f '/runtime/versions/[^/ ]+/t3( |$)' > /dev/null || server=$?
        if [ "$server" = 1 ]; then
          PATH="${upPath}" "$t3" up --lan --yes || warnEcho "t3code: t3 up failed. Run: t3 up --lan --yes"
        else
          warnEcho "t3code: there is no ${baseNameOf unit}, and a T3 server is running or the process list could not be read. t3 up was not run: it would restart a running server and stop running agent turns. When no turn is running: t3 up --lan --yes"
        fi
      fi''}
    ${lib.optionalString (noSession != null) "elif [[ ! -v DRY_RUN ]]; then\n  warnEcho ${lib.escapeShellArg noSession}\n"}fi
  '';
in
{
  name = "T3 Code server";
  description = "Serves T3 Code agent threads. Locks out a T3 desktop app on the same box. T3's installer puts t3 in ~/.local/bin, and t3 up writes its own systemd user unit on Linux and launchd agent on a Mac with a GUI. A headless Mac runs t3 as a launchd daemon for the user, started at boot.";
  platforms = [ "linux" "darwin" ];
  requires = [ "node" ];
  conflicts = [ "window-manager" ];

  linux.home = { config, lib, pkgs, ... }:
    let home = config.home.homeDirectory; in
    {
      xdg.configFile."systemd/user/t3code.service.d/path.conf".text = ''
        [Service]
        Environment=PATH=%h/.local/bin:%h/.cargo/bin:${pkgs.nodejs}/bin:/usr/local/bin:/usr/bin
      '';

      home.activation.t3code = lib.hm.dag.entryAfter [ "linkGeneration" ] (activation {
        inherit lib pkgs home;
        session = "/usr/bin/systemctl --user show-environment";
        unit = "${config.xdg.configHome}/systemd/user/t3code.service";
        pgrep = "${pkgs.procps}/bin/pgrep";
        upPath = "/usr/local/bin:/usr/bin:/bin:$PATH";
      });
    };

  darwin.home = { config, lib, pkgs, machine, ... }:
    let
      home = config.home.homeDirectory;
      inherit (machine.traits) headless;
    in
    {
      dotfiles.services.t3code = lib.mkIf headless {
        description = "T3 Code server, started at boot";
        command = [ "${home}/.local/bin/t3" "--lan" "--no-browser" ];
        requiresFile = ".local/bin/t3";
        restart = "always";
        extraPath = [ "${home}/.cargo/bin" "/run/current-system/sw/bin" ];
        launchd.WorkingDirectory = home;
      };

      home.activation.t3code = lib.hm.dag.entryAfter [ "linkGeneration" ] (activation {
        inherit lib pkgs home;
        up = !headless;
        session = if headless then "true" else "/bin/launchctl print gui/$UID";
        unit = "${home}/Library/LaunchAgents/com.t3tools.t3code.service.plist";
        pgrep = "/usr/bin/pgrep";
        noSession = "t3code: ${machine.user.name} has no GUI login session, so launchd cannot run the T3 agent and T3 was not set up. Log in on the Mac once, or turn on automatic login, then switch again.";
        upPath = "${home}/.local/bin:${home}/.cargo/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      });
    };

  inventory = {
    starts = {
      linux = [ "t3code.service (user, written by t3 up)" ];
      darwin = [ "com.t3tools.t3code.service (launchd agent, written by t3 up) with a GUI; t3code (launchd daemon as the user) on a headless Mac" ];
    };
    files = [ ".config/systemd/user/t3code.service.d/path.conf" ];
    scripts = [
      {
        id = "60-t3code-service";
        root = false;
        note = "T3's installer where t3 is missing, and t3 up where there is no unit and no running server. The version is T3's own";
      }
    ];
    packages = {
      linux = [ "t3 (T3's installer, into ~/.t3)" ];
    };
  };
}
