{ config, lib, pkgs, machine, ... }:
let
  inherit (lib) mkOption types;
  inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
  home = config.home.homeDirectory;

  service = { name, ... }: {
    options = {
      description = mkOption { type = types.str; default = name; };
      command = mkOption {
        type = types.listOf types.str;
        description = "The argv to run. No shell.";
      };
      path = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Packages put first on PATH. The user's profile and ~/.local/bin follow.";
      };
      environment = mkOption { type = types.attrsOf types.str; default = { }; };
      restart = mkOption { type = types.enum [ "on-failure" "always" ]; default = "on-failure"; };
      restartSec = mkOption { type = types.ints.positive; default = 5; };
      requiresFile = mkOption {
        type = types.coercedTo types.str lib.singleton (types.listOf types.str);
        default = [ ];
        example = ".config/infisical/machine.env";
        description = "Paths under the home directory. The service stays down while any of them is missing.";
      };
      credentials = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Declared credentials a pre-start step writes, each as a 0600 file named for it, into a private runtime directory whose path is in DOTFILES_CREDENTIALS_DIRECTORY. A credential no tier holds gets no file, and the service still starts.";
      };
      extraPath = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Directories added to PATH after the user's profile, for tools the service starts that live outside it.";
      };
      systemd = mkOption {
        type = types.attrsOf (types.attrsOf types.anything);
        default = { };
        description = "Extra unit sections, merged into the generated unit on Linux.";
      };
      launchd = mkOption {
        type = types.attrsOf types.anything;
        default = { };
        description = "Extra launchd keys, merged into the generated agent on darwin.";
      };
    };
  };

  credential = "${config.dotfiles.credential}/bin/dotfiles-credential";
  credentialDir = name: "dotfiles-credentials-${name}";
  withFiles = name: s: command:
    if s.credentials == [ ] then command
    else [ "/bin/sh" "-c" ''d="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)${credentialDir name}" && ${credential} files "$d" ${lib.escapeShellArgs s.credentials} && DOTFILES_CREDENTIALS_DIRECTORY=$d exec "$@"'' "sh" ] ++ command;

  environmentOf = s: s.environment // {
    PATH = lib.concatStringsSep ":" (
      map (p: "${p}/bin") s.path
      ++ [ "${home}/.local/bin" "${config.home.profileDirectory}/bin" ]
      ++ s.extraPath
      ++ lib.optional isDarwin "/opt/homebrew/bin"
      ++ [ "/usr/local/bin" "/usr/bin" "/bin" ]
    );
  };
in
{
  options.dotfiles.services = mkOption {
    type = types.attrsOf (types.submodule service);
    default = { };
    description = "Long-running user services that start at login on every platform, and at boot on a headless Mac.";
  };

  options.dotfiles.launchd = mkOption {
    type = types.attrsOf types.anything;
    readOnly = true;
    description = "darwin: the launchd job of each service. A launchd agent with a GUI, and on a headless Mac a daemon that modules/darwin.nix runs as the user.";
  };

  config = {
    systemd.user.services = lib.mkIf isLinux (lib.mapAttrs
      (name: s: lib.mkMerge [
        {
          Unit = { Description = s.description; }
            // lib.optionalAttrs (s.requiresFile != [ ]) { ConditionPathExists = map (file: "%h/${file}") s.requiresFile; };
          Service = {
            ExecStart = lib.escapeShellArgs s.command;
            Restart = s.restart;
            RestartSec = s.restartSec;
            Environment = lib.mapAttrsToList (k: v: "${k}=${v}") (environmentOf s
              // lib.optionalAttrs (s.credentials != [ ]) { DOTFILES_CREDENTIALS_DIRECTORY = "%t/${credentialDir name}"; });
          } // lib.optionalAttrs (s.credentials != [ ]) {
            RuntimeDirectory = credentialDir name;
            RuntimeDirectoryMode = "0700";
            ExecStartPre = lib.escapeShellArgs ([ credential "files" "%t/${credentialDir name}" ] ++ s.credentials);
          };
          Install.WantedBy = [ "default.target" ];
        }
        s.systemd
      ])
      config.dotfiles.services);

    launchd.agents = lib.mkIf (isDarwin && !(machine.traits.headless or false)) (lib.mapAttrs
      (_: job: { enable = true; config = job; })
      config.dotfiles.launchd);

    dotfiles.launchd = lib.mapAttrs
      (name: s: {
        ProgramArguments =
          if lib.length s.requiresFile > 1 then
            [ "/bin/sh" "-c" "${lib.concatMapStrings (file: "/bin/wait4path ${lib.escapeShellArg "${home}/${file}"} && ") s.requiresFile}exec \"$@\"" "sh" ] ++ withFiles name s s.command
          else withFiles name s s.command;
        EnvironmentVariables = environmentOf s;
        RunAtLoad = s.requiresFile == [ ];
        KeepAlive =
          if s.requiresFile != [ ] then { PathState = lib.genAttrs (map (file: "${home}/${file}") s.requiresFile) (_: true); }
          else if s.restart == "always" then true
          else { SuccessfulExit = false; };
        ThrottleInterval = s.restartSec;
        ProcessType = "Background";
        StandardOutPath = "${home}/Library/Logs/${name}.log";
        StandardErrorPath = "${home}/Library/Logs/${name}.log";
      } // s.launchd)
      config.dotfiles.services;
  };
}
