{ config, options, lib, pkgs, machine, owners, modulesPath, ... }:
let
  inherit (lib) mkOption types;
  who = import ./who.nix { inherit lib options owners modulesPath; };
  declarers = name: who.named (who.definers options.dotfiles.credentials name);
  noProvider = "this machine has no secrets provider (secrets = \"none\")";
  tool = import ./credential-tool.nix { inherit pkgs; };

  method = {
    file = mkOption { type = types.either types.bool types.str; default = false; description = "The consumer reads a 0600 file in a private runtime directory. A string names the variable that carries the file's path; true means a step of the flake writes it, such as an activation step or a service's pre-start."; };
    env = mkOption { type = types.nullOr types.str; default = null; description = "The variable a wrapper sets before it execs the consumer."; };
    stdin = mkOption { type = types.bool; default = false; description = "The consumer reads the value on stdin."; };
    session = mkOption { type = types.nullOr types.str; default = null; description = "The variable every session carries."; };
    keyring = mkOption { type = types.bool; default = false; description = "The consumer reads the item from the local store itself."; };
    login = mkOption { type = types.nullOr types.str; default = null; description = "The consumer's own login command. The value never passes through the flake."; };
  };

  credential = types.submodule {
    options = {
      description = mkOption { type = types.str; };
      deliver = mkOption { type = types.submodule { options = method; }; default = { }; };
      to = mkOption { type = types.nullOr types.str; default = null; description = "The consumer, when it is not the declaring solution."; };
      derive = mkOption { type = types.nullOr types.str; default = null; description = "A command that prints the value from another tool's own login. The last source before the manual step."; };
      probe = mkOption { type = types.nullOr types.str; default = null; description = "For a login: a command whose exit status says whether the login exists. It never prints a value."; };
    };
  };
in
{
  options.dotfiles = {
    credentials = mkOption {
      type = types.attrsOf credential;
      default = { };
      description = "Credentials a solution's consumer needs, by name, such as \"tailscale/work/authkey\", and the ways the consumer can take them. Every one is optional. Only names reach the store.";
    };

    credentialProvider = {
      get = mkOption {
        type = types.path;
        default = pkgs.writeShellScript "no-credential-provider" ''
          echo ${lib.escapeShellArg noProvider} >&2
          exit 3
        '';
        description = "Program that prints the value of the named credential on stdout, or one line on stderr saying why it cannot and exits non-zero.";
      };
      has = mkOption {
        type = types.path;
        default = pkgs.writeShellScript "no-credential-presence" ''
          echo ${lib.escapeShellArg noProvider} >&2
          exit 4
        '';
        description = "Program that, given names, prints the ones its provider holds, one per line, and never a value. It exits 4 with one line on stderr when the machine is not set up to ask the provider, and 3 when the provider cannot be asked.";
      };
      unconfigured = mkOption {
        type = types.nullOr types.str;
        default = noProvider;
        description = "Why this machine cannot ask its provider, as far as the flake alone can tell, or null when it can try.";
      };
    };

    sessionSource = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Program that prints the provider's whole env project as one JSON object per line, a new line whenever it changes. The session env writer merges it with the declared session credentials.";
    };

    credentialStore = mkOption {
      type = types.enum [ "secret-service" "keychain" "file" ];
      default =
        if machine.traits.headless or false then "file"
        else if pkgs.stdenv.hostPlatform.isDarwin then "keychain"
        else "secret-service";
      description = "The machine's local store, asked first: Secret Service on a Linux desktop, the login Keychain on a Mac with a GUI, and a 0600 file per credential under ~/.local/state/dotfiles/credentials on a headless machine.";
    };

    credential = mkOption {
      type = types.package;
      readOnly = true;
      description = "dotfiles-credential: resolves a declared credential through the local store, the provider, derive and the manual step.";
    };

    withCredentials = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      description = "Given credential names, the command prefix that runs a consumer with each one delivered by the methods its declaration names: env, a file whose path is in a variable, or stdin.";
    };

    secretsReport = mkOption {
      type = types.raw;
      readOnly = true;
      description = "The declared credentials of this machine, by name, with the solutions that declare them.";
    };

    secretsAudit = mkOption {
      type = types.path;
      readOnly = true;
      description = "Program that reports, by consumer and by name only, where each declared credential would come from.";
    };
  };

  config.dotfiles = {
    secretsReport = {
      machine = machine.name or "";
      provider = machine.traits.secrets or "none";
      store = config.dotfiles.credentialStore;
      inherit (config.dotfiles.credentialProvider) unconfigured;
      credentials = lib.mapAttrs
        (name: c: { inherit (c) description to derive probe deliver; solutions = declarers name; })
        config.dotfiles.credentials;
      sessionFile = ".config/dotfiles/env.sh";
      sessionKeys = "__DOTFILES_KEYS";
    };

    credential = tool.program config.dotfiles.secretsReport {
      runtime = { inherit (config.dotfiles.credentialProvider) get has; };
      toolPath = lib.optionalString (config.dotfiles.credentialStore == "secret-service") "${pkgs.libsecret}/bin";
    };

    secretsAudit = tool.audit config.dotfiles.credential;

    withCredentials = names:
      let
        flags = name:
          let
            c = config.dotfiles.credentials.${name} or (throw "withCredentials: ${name} is not a declared credential");
            inherit (c) deliver;
          in
          lib.optionals (deliver.env != null) [ "--env" "${name}=${deliver.env}" ]
          ++ lib.optionals (lib.isString deliver.file) [ "--file" "${name}=${deliver.file}" ]
          ++ lib.optionals deliver.stdin [ "--stdin" name ];
      in
      lib.escapeShellArgs ([ "${config.dotfiles.credential}/bin/dotfiles-credential" "run" ] ++ lib.concatMap flags names ++ [ "--" ]);
  };

  config.home.packages = [ config.dotfiles.credential ];
  config.home.extraBuilderCommands = "ln -s ${config.dotfiles.secretsAudit} $out/dotfiles-secrets";
}
