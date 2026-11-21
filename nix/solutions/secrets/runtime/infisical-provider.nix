{
  name = "Infisical secrets provider";
  description = "Reads a named secret from Infisical at activation with the machine identity in ~/.config/infisical/machine.env, and takes only the client id and secret from that file. The name tailscale/work/authkey is the secret AUTHKEY in the folder /tailscale/work, outside the folder whose keys the session env writer exports into every shell. Project and environment come from the machine's private entry.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "infisical";
  requires = [ "infisical-sync" ];

  home = { lib, pkgs, machine, ... }:
    let
      infisical = import ./_infisical.nix { inherit pkgs machine; };
      project = if infisical.project == null then { } else infisical.project;
    in
    {
      dotfiles.credentialProvider.unconfigured =
        if infisical.project == null then "no Infisical project for this machine (private.infisical.projectId and .environment in its entry)" else null;

      dotfiles.credentialProvider.has = pkgs.writeShellScript "infisical-presence" ''
        project=${lib.escapeShellArg (project.projectId or "")}
        environment=${lib.escapeShellArg (project.environment or "")}

        [ -n "$project" ] && [ -n "$environment" ] \
          || { echo "no Infisical project for this machine (private.infisical.projectId and .environment in its entry)" >&2; exit 4; }
        ${infisical.readCredentials} > /dev/null || exit 4
        token=$(${infisical.login}) || exit 3

        declare -A held=() asked=()
        for name in "$@"; do
          ${infisical.locate}
          if [ -z "''${asked[$folder]+x}" ]; then
            asked[$folder]=1
            keys=$(
              set -o pipefail
              INFISICAL_TOKEN=$token ${pkgs.coreutils}/bin/timeout 30 \
                infisical export --format=json --silent --projectId "$project" --env "$environment" --path "$folder" 2> /dev/null \
                | ${pkgs.jq}/bin/jq -r '[.[] | select(((.value // .secretValue) // "") != "") | (.key // .secretKey)] | .[]' 2> /dev/null
            ) || { echo "could not read $folder from Infisical (offline, or the identity cannot see it)" >&2; exit 3; }
            while IFS= read -r found; do [ -z "$found" ] || held["$folder/$found"]=1; done <<< "$keys"
          fi
          if [ -n "''${held[$folder/$key]+x}" ]; then printf '%s\n' "$name"; fi
        done
      '';

      dotfiles.credentialProvider.get = pkgs.writeShellScript "infisical-secret" ''
        name=$1
        ${infisical.locate}
        project=${lib.escapeShellArg (project.projectId or "")}
        environment=${lib.escapeShellArg (project.environment or "")}
        fail() { echo "$*" >&2; exit 3; }

        [ -n "$project" ] && [ -n "$environment" ] \
          || fail "no Infisical project for this machine (private.infisical.projectId and .environment in its entry)"
        token=$(${infisical.login}) || exit 3

        INFISICAL_TOKEN=$token ${pkgs.coreutils}/bin/timeout 30 \
          infisical export --format=json --silent --projectId "$project" --env "$environment" --path "$folder" 2> /dev/null \
          | ${pkgs.jq}/bin/jq -je --arg k "$key" 'first(.[] | select((.key // .secretKey) == $k) | (.value // .secretValue) | select(. != ""))' 2> /dev/null
        read -r fetched found <<< "''${PIPESTATUS[*]}"
        [ "$fetched" = 0 ] || fail "could not read $folder from Infisical (offline, or the identity cannot see it)"
        [ "$found" = 0 ] || fail "Infisical has no $key in $folder"
      '';
    };

  inventory = { };
}
