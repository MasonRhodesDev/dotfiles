{
  name = "Infisical env project";
  description = "Polls the machine's Infisical project, environment and path, rendered into ~/.config/infisical/project.json from its private entry, and hands the whole env project to the session env writer. infisical-exec runs one command with it. Takes only the client id and secret from ~/.config/infisical/machine.env. Inert without either file.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "infisical";

  home = { lib, pkgs, machine, ... }:
    let
      infisical = import ../_infisical.nix { inherit pkgs machine; };
      envSync = pkgs.replaceVars ./infisical-env-sync.py { inherit (infisical) login; };
    in
    {
      home.packages = [ pkgs.infisical ];

      dotfiles.warnings = lib.optional (infisical.warning != null) infisical.warning;
      home.file.${infisical.projectFile} = lib.mkIf (infisical.project != null) { text = builtins.toJSON infisical.project; };

      dotfiles.sessionSource = pkgs.writeShellScript "infisical-env-project" ''exec ${pkgs.python3}/bin/python3 ${envSync}'';

      home.file.".local/bin/infisical-exec" = {
        source = pkgs.replaceVars ./infisical-exec { inherit (infisical) login; jq = "${pkgs.jq}/bin/jq"; };
        executable = true;
      };
      home.file.".claude/skills/infisical-secrets/SKILL.md" = lib.mkIf (lib.elem "claude-code" machine.enabled) { source = ./SKILL.md; };
    };

  inventory = {
    files = [
      ".config/infisical/project.json"
      ".local/bin/infisical-exec"
      ".claude/skills/infisical-secrets/SKILL.md"
    ];
    packages = {
      linux = [ "infisical" ];
      darwin = [ "infisical" ];
    };
  };
}
