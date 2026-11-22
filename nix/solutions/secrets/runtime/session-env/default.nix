{
  name = "Session env";
  description = "One file, ~/.config/dotfiles/env.sh (0600), that every bash reads: the provider's whole env project, when the machine has one, plus each declared session credential resolved through the credential chain, rewritten when either changes. On a Linux desktop the keys reach the systemd user session by name, never by value on a command line.";
  platforms = [ "linux" "darwin" ];

  home = { config, lib, pkgs, machine, ... }:
    let
      wanted = lib.mapAttrs (_: c: c.deliver.session) (lib.filterAttrs (_: c: c.deliver.session != null) config.dotfiles.credentials);
      mode = if pkgs.stdenv.hostPlatform.isLinux && !machine.traits.headless then "import" else "file-only";
    in
    {
      dotfiles.services.dotfiles-session-env = {
        description = "Write ~/.config/dotfiles/env.sh from the provider's env project and the declared session credentials";
        command = [
          "${pkgs.python3}/bin/python3"
          "${./session-env.py}"
          (if config.dotfiles.sessionSource == null then "-" else "${config.dotfiles.sessionSource}")
          "${config.dotfiles.credential}/bin/dotfiles-credential"
          "${pkgs.writeText "session-credentials.json" (builtins.toJSON wanted)}"
          mode
        ];
        restart = "always";
        restartSec = 30;
        systemd.Unit = {
          Wants = [ "network-online.target" ];
          After = [ "network-online.target" ];
        };
      };

      home.file.".bashrc.d/zz-dotfiles-env.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { text = ''
        __dotfiles_env_file=$HOME/.config/dotfiles/env.sh
        export BASH_ENV=$__dotfiles_env_file

        __dotfiles_env_reload() {
            local f=$__dotfiles_env_file stamp k old
            [ -r "$f" ] || return 0
            stamp=$(${pkgs.coreutils}/bin/stat -c %Y.%s "$f" 2>/dev/null) || return 0
            [ "$stamp" = "''${__dotfiles_env_stamp-}" ] && return 0
            old=" ''${__DOTFILES_KEYS-} "
            . "$f"
            for k in $old; do
                case " $__DOTFILES_KEYS " in *" $k "*) ;; *) unset "$k" ;; esac
            done
            __dotfiles_env_stamp=$stamp
        }

        __dotfiles_env_reload
        case ";''${PROMPT_COMMAND-};" in
            *";__dotfiles_env_reload;"*) ;;
            *) PROMPT_COMMAND="__dotfiles_env_reload''${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
        esac
      ''; };
    };
}
