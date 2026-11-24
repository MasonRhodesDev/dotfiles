{
  name = "Bitwarden secrets provider";
  description = "Reads a named secret from Bitwarden Secrets Manager at activation with the machine access token in ~/.config/bitwarden/machine.env, and takes only BWS_ACCESS_TOKEN from that file. The name tailscale/work/authkey is the secret whose key is exactly tailscale/work/authkey in the machine's secrets project, a project apart from the env project that the session env writer exports into every shell. Project ids and the server come from the machine's private entry.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "bitwarden";
  requires = [ "bitwarden-sync" ];

  home = { lib, pkgs, machine, ... }:
    let
      bitwarden = import ./_bitwarden.nix { inherit lib pkgs machine; };
      jq = "${pkgs.jq}/bin/jq";
    in
    {
      dotfiles.credentialProvider.unconfigured =
        if bitwarden.secretsProject == "" then "no Bitwarden secrets project for this machine (private.bitwarden.secretsProject in its entry)" else null;

      dotfiles.credentialProvider.has = pkgs.writeShellScript "bitwarden-presence" ''
        project=${lib.escapeShellArg bitwarden.secretsProject}

        [ -n "$project" ] || { echo "no Bitwarden secrets project for this machine (private.bitwarden.secretsProject in its entry)" >&2; exit 4; }
        ${bitwarden.readToken} > /dev/null || exit 4

        keys=$(
          set -o pipefail
          ${bitwarden.list} "$project" \
            | { ${jq} -r '[.[] | select(.value != "") | .key] | group_by(.) | map(select(length == 1) | .[0]) | .[]' 2> /dev/null \
              || { echo "Bitwarden answered with something other than a list of secrets" >&2; exit 3; }; }
        ) || exit 3
        for name in "$@"; do
          if ${pkgs.gnugrep}/bin/grep -qxF -- "$name" <<< "$keys"; then printf '%s\n' "$name"; fi
        done
      '';

      dotfiles.credentialProvider.get = pkgs.writeShellScript "bitwarden-secret" ''
        name=$1
        project=${lib.escapeShellArg bitwarden.secretsProject}
        fail() { echo "$*" >&2; exit 3; }

        [ -n "$project" ] || fail "no Bitwarden secrets project for this machine (private.bitwarden.secretsProject in its entry)"
        listed=$(${bitwarden.list} "$project") || exit 3

        count=$(printf '%s' "$listed" | ${jq} --arg k "$name" '[.[] | select(.key == $k and .value != "")] | length' 2> /dev/null) \
          || fail "Bitwarden answered with something other than a list of secrets"
        case $count in
          0) fail "Bitwarden has no $name in the project $project" ;;
          1) ;;
          *) fail "Bitwarden has $count secrets named $name in the project $project, so none is used" ;;
        esac
        printf '%s' "$listed" | ${jq} -j --arg k "$name" 'first(.[] | select(.key == $k and .value != "") | .value)'
      '';
    };
}
