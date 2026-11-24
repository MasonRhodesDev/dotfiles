let
  clientFor = pkgs: pkgs.writeScript "t3-desktop-client"
    (builtins.replaceStrings [ "@jq@" "@procps@" ] [ "${pkgs.jq}" "${pkgs.procps}" ] (builtins.readFile ./t3-desktop-client));

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
        ${pgrep} -U "$UID" -f '/runtime/versions/[^/ ]+/t3( |$)|apps/server/dist/bin\.mjs' > /dev/null || server=$?
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
  description = "Serves T3 Code agent threads. T3's installer puts t3 in ~/.local/bin, and t3 up writes its own systemd user unit on Linux, started at boot through linger, and launchd agent on a Mac with a GUI. A headless Mac runs t3 as a launchd daemon for the user, started at boot. On a Linux desktop the service owns every session and the T3 app is only its client: the app's Local environment is off, and a login unit pairs the app with the service when it is not paired.";
  platforms = [ "linux" "darwin" ];
  requires = [ "node" ];

  linux.root = { lib, machine, ... }: {
    script = "loginctl enable-linger ${lib.escapeShellArg machine.user.name}";
  };

  linux.home = { config, lib, pkgs, machine, ... }:
    let
      home = config.home.homeDirectory;
      inherit (machine.traits) headless;
      session = "/usr/bin/systemctl --user show-environment";
      client = clientFor pkgs;
    in
    lib.mkMerge [
      {
        xdg.configFile."systemd/user/t3code.service.d/path.conf".text = ''
          [Service]
          Environment=PATH=%h/.local/bin:%h/.cargo/bin:${pkgs.nodejs}/bin:/usr/local/bin:/usr/bin
        '';

        home.activation.t3code = lib.hm.dag.entryAfter [ "linkGeneration" ] (activation {
          inherit lib pkgs home session;
          up = headless;
          unit = "${config.xdg.configHome}/systemd/user/t3code.service";
          pgrep = "${pkgs.procps}/bin/pgrep";
          upPath = "/usr/local/bin:/usr/bin:/bin:$PATH";
        });
      }
      (lib.mkIf (!headless) {
        home.file.".local/bin/t3-desktop-client".source = client;

        home.activation.t3codeClient = lib.hm.dag.entryAfter [ "t3code" ] ''
          if [[ ! -v DRY_RUN ]] && ${session} > /dev/null 2>&1 && [ -x ${lib.escapeShellArg "${home}/.local/bin/t3"} ]; then
            PATH="/usr/local/bin:/usr/bin:/bin:$PATH" ${client} converge || warnEcho "t3code: the T3 app is not a client of t3code.service yet. See the line above."
          fi
        '';

        systemd.user.services.t3-desktop-pair = {
          Unit = {
            Description = "Pair the T3 app with this machine's T3 service";
            After = [ "graphical-session.target" "t3code.service" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "%h/.local/bin/t3-desktop-client pair";
            Environment = [ "PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ];

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

  checks = { pkgs, ... }: {
    t3-desktop-client = pkgs.runCommand "t3-desktop-client" { } ''
      export HOME=$PWD/fixture T3CODE_HOME=$PWD/fixture/.t3
      userdata=$T3CODE_HOME/userdata
      mkdir -p "$HOME/.local/bin" "$userdata"
      cat > "$HOME/.local/bin/t3" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "t3 $*" >> "$HOME/calls"
      EOF
      chmod +x "$HOME/.local/bin/t3"
      client="${pkgs.bash}/bin/bash ${clientFor pkgs}"
      failures=0
      fail() { echo "FAIL $1"; cat said; failures=$((failures + 1)); }
      settings='{"mainWindowBounds":{"x":0,"y":0},"mainWindowMaximized":true}'
      reset() { echo "$settings" > "$userdata/desktop-settings.json"; rm -f "$HOME/calls" "$userdata/desktop-last-started-version"; }
      untouched() { [ "$(cat "$userdata/desktop-settings.json")" = "$settings" ] && [ ! -e "$HOME/calls" ]; }
      owned_by() { echo "{\"pid\":$1}" > "$userdata/server-runtime.json"; }
      run() { status=0; $client "$@" 2> said || status=$?; }

      reset; owned_by $$
      run converge
      [ "$status" = 2 ] && untouched && grep -q "outside t3code.service" said || fail "a T3 server outside the service keeps the home, the setting and t3 untouched"

      ${pkgs.bash}/bin/bash -c 'sleep 300; :' t3code apps/server/dist/bin.mjs &
      app=$!
      until ${pkgs.procps}/bin/ps -o comm= --ppid "$app" | grep -qx sleep; do sleep 0.1; done
      reset; owned_by "$app"
      run converge
      [ "$status" = 2 ] && untouched && grep -q "t3-desktop-client takeover" said || fail "converge leaves a T3 app that hosts its own server alone and names the takeover"
      run pair
      [ "$status" = 0 ] && untouched || fail "the login unit leaves a T3 app that hosts its own server alone and does not fail"
      run takeover
      [ "$status" = 1 ] && untouched && kill -0 "$app" && grep -q "running agents or terminals" said || fail "takeover never quits a T3 app whose server runs agents or terminals"
      ${pkgs.procps}/bin/pkill -P "$app"; kill "$app"

      reset; rm -f "$userdata/server-runtime.json"; echo 0.1.10 > "$userdata/desktop-last-started-version"
      run converge
      [ "$status" = 1 ] && [ "$(cat "$userdata/desktop-settings.json")" = "$settings" ] && [ ! -e "$HOME/calls" ] && grep -q "needs 0.1.11" said || fail "an app too old for the Local environment setting gets neither the setting nor the service"

      [ "$failures" = 0 ] && touch $out
    '';
  };
}
