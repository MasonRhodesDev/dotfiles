{ lib, pkgs, machine }:
let
  given = machine.private.bitwarden or { };
  serverUrl = given.serverUrl or "";
  missing = builtins.filter (key: (given.${key} or "") == "") [ "envProject" "secretsProject" ];
  readToken = ''${import ./_credentials.nix { inherit pkgs; }} "$HOME/.config/bitwarden/machine.env" "Bitwarden Secrets Manager" BWS_ACCESS_TOKEN'';
in
{
  warning =
    if missing == [ ] then null
    else "${machine.name}: secrets = \"bitwarden\", and its private entry sets no ${lib.concatMapStringsSep " and no " (key: "private.bitwarden.${key}") missing}, so Bitwarden env sync, bitwarden-exec and Bitwarden secrets stay inert";

  envProject = given.envProject or "";
  secretsProject = given.secretsProject or "";

  projectFile = ".config/bitwarden/project.json";

  inherit readToken;

  package = (import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfreePackages = [ "bws" ];
  }).bws;

  list = pkgs.writeShellScript "bitwarden-list" ''
    project=$1
    credentials=$HOME/.config/bitwarden/machine.env
    fail() { echo "$*" >&2; exit 3; }

    command -v bws >/dev/null 2>&1 || fail "the bws CLI is not installed"
    token=$(${readToken}) || exit 3

    BWS_ACCESS_TOKEN=$token ${pkgs.coreutils}/bin/env -u BWS_SERVER_URL -u BWS_PROFILE -u BWS_CONFIG_FILE \
      ${pkgs.coreutils}/bin/timeout 30 bws secret list "$project" --output json --color no ${lib.optionalString (serverUrl != "") "--server-url ${lib.escapeShellArg serverUrl}"} 2> /dev/null \
      || fail "could not list the Bitwarden project $project (offline, a wrong project id, or the token in $credentials cannot see it)"
  '';
}
