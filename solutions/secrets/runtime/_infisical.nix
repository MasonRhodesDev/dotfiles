{ pkgs, machine }:
let
  readCredentials = ''${import ./_credentials.nix { inherit pkgs; }} "$HOME/.config/infisical/machine.env" Infisical INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET'';
  given = machine.private.infisical or { };
  missing = builtins.filter (key: (given.${key} or "") == "") [ "projectId" "environment" ];
in
{
  warning =
    if missing == [ ] then null
    else "${machine.name}: secrets = \"infisical\", and its private entry sets no ${pkgs.lib.concatMapStringsSep " and no " (key: "private.infisical.${key}") missing}, so Infisical env sync, infisical-exec, the secret inbox and Infisical secrets stay inert";

  project =
    if (given.projectId or "") != "" && (given.environment or "") != ""
    then { inherit (given) projectId environment; path = given.path or "/"; }
    else null;

  projectFile = ".config/infisical/project.json";

  inherit readCredentials;

  locate = ''folder=/''${name%/*} key=''${name##*/} key=''${key^^} key=''${key//-/_}'';

  login = pkgs.writeShellScript "infisical-login" ''
    credentials=$HOME/.config/infisical/machine.env
    fail() { echo "$*" >&2; exit 3; }

    command -v infisical >/dev/null 2>&1 || fail "the infisical CLI is not installed"

    { IFS= read -r id && IFS= read -r secret; } < <(${readCredentials}) || exit 3

    token=$(
      INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=$id INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=$secret \
        ${pkgs.coreutils}/bin/timeout 30 infisical login --method=universal-auth --silent --plain 2> /dev/null
    )
    [ -n "$token" ] || fail "Infisical refused the login or could not be reached (offline, or the identity in $credentials is wrong)"
    printf '%s\n' "$token"
  '';
}
