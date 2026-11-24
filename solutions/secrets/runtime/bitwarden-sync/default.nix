{
  name = "Bitwarden env project";
  description = "Polls the machine's Bitwarden Secrets Manager env project, rendered into ~/.config/bitwarden/project.json from its private entry, and hands it to the session env writer. bitwarden-exec runs one command with those secrets. Takes only BWS_ACCESS_TOKEN from ~/.config/bitwarden/machine.env. Idle with one line saying why while bws, the token or the project is unusable.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "bitwarden";

  home = { lib, pkgs, machine, ... }:
    let
      bitwarden = import ../_bitwarden.nix { inherit lib pkgs machine; };
      env = pkgs.replaceVars ./bitwarden-env.py { inherit (bitwarden) list; };
      python = "${pkgs.python3}/bin/python3";
    in
    {
      home.packages = [ bitwarden.package ];
      dotfiles.warnings = lib.optional (bitwarden.warning != null) bitwarden.warning;

      home.file.${bitwarden.projectFile} = lib.mkIf (bitwarden.envProject != "") { text = builtins.toJSON { inherit (bitwarden) envProject; }; };

      dotfiles.sessionSource = pkgs.writeShellScript "bitwarden-env-project" ''exec ${python} ${env}'';

      home.file.".local/bin/bitwarden-exec" = {
        source = pkgs.writeShellScript "bitwarden-exec" ''exec ${python} ${env} exec "$@"'';
        executable = true;
      };
    };
}
