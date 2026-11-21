{ pkgs }:
pkgs.writeShellScript "machine-env" ''
  credentials=$1 service=$2
  shift 2
  fail() { echo "$*" >&2; exit 3; }

  [ -r "$credentials" ] || fail "not logged in to $service: $credentials is missing"

  declare -A found=()
  while IFS== read -r k v || [ -n "$k" ]; do
    k=''${k#"''${k%%[![:space:]]*}"}
    if [[ $k == export[[:space:]]* ]]; then k=''${k#export}; fi
    k=''${k//[[:space:]]/}
    v=''${v#"''${v%%[![:space:]\"\']*}"} v=''${v%"''${v##*[![:space:]\"\']}"}
    for want in "$@"; do
      [ "$k" = "$want" ] && found[$k]=$v
    done
  done < "$credentials"
  for want in "$@"; do
    [ -n "''${found[$want]-}" ] || fail "$credentials sets no $want, so $service is not asked"
  done
  for want in "$@"; do
    printf '%s\n' "''${found[$want]}"
  done
''
