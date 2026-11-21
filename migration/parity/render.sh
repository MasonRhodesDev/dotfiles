#!/usr/bin/env bash
# Render what chezmoi deploys for each profile in profiles/ from a pinned commit,
# and write golden/<profile>.manifest and golden/<profile>.scripts.
# usage: render.sh [--check] --profile-data DIR [profile...]
#   --profile-data DIR   per-machine values for the profiles' @placeholders@ (or $PARITY_PROFILE_DATA)
#   --check              render and compare with the committed goldens; write nothing
# env: PARITY_COMMIT, PARITY_OUT
set -euo pipefail

check=
data=${PARITY_PROFILE_DATA:-}
while [ $# -gt 0 ]; do
  case $1 in
    --check) check=1; shift ;;
    --profile-data) data=${2:?--profile-data needs a directory}; shift 2 ;;
    -*) echo "render.sh: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done
[ -d "$data" ] || { echo "render.sh: --profile-data DIR is required (one <profile>.toml per profile, shaped like profile-data.example/)" >&2; exit 2; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(git -C "$here" rev-parse --show-toplevel)
commit=${PARITY_COMMIT:-284637c766c3ad22391c18ea7f119cd8fd6ad8eb}
out=${PARITY_OUT:-${TMPDIR:-/tmp}/chezmoi-parity}
chezmoi=$(command -v chezmoi) || { echo "render.sh: needs chezmoi on PATH" >&2; exit 2; }
jq=$(command -v jq) || { echo "render.sh: needs jq on PATH" >&2; exit 2; }
path="$(dirname "$chezmoi"):$(dirname "$jq"):/usr/bin:/bin"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
src=$work/src
mkdir -p "$src" "$work/home" "$work/golden" "$out"
git -C "$repo" archive "$commit" | tar -x -C "$src"

# Each profile file is the complete [data] a machine's chezmoi.toml carries, so
# the config template that builds it from Bitwarden and prompts never runs.
rm "$src/.chezmoi.toml.tmpl"

[ $# -gt 0 ] || set -- "$here"/profiles/*.toml
profiles=() configs=()
for file in "$@"; do
  [ -f "$file" ] || file=$here/profiles/$file.toml
  profile=$(basename "$file" .toml)
  { printf 'umask = 0o022\n[warnings]\nconfigFileTemplateHasChanged = false\n\n'
    python3 -I "$here/prepare.py" fill "$file" "$data"; } >"$work/$profile.toml"
  profiles+=("$profile") configs+=("$work/$profile.toml")
done

# Answer stat from the profile, then refuse every action that could still read the host.
python3 -I "$here/prepare.py" export "$src" "${configs[@]}"

for profile in "${profiles[@]}"; do
  cfg=$work/$profile.toml

  # chezmoi writes symlinks with mode 000 and bsdtar applies it, which breaks
  # readlink on macOS; tarfile leaves symlink modes alone everywhere.
  untar() {
    python3 -I -c 'import sys, tarfile
kw = {"filter": "fully_trusted"} if hasattr(tarfile, "fully_trusted_filter") else {}
tarfile.open(fileobj=sys.stdin.buffer, mode="r|").extractall(sys.argv[1], **kw)' "$1"
  }

  cz() {
    env -i HOME="$work/home" PATH="$path" "$chezmoi" --no-tty --source "$src" --destination "$work/home" \
      --config "$cfg" --persistent-state "$work/$profile.boltdb" --cache "$work/cache" "$@"
  }

  rm -rf "$out/$profile" "$out/$profile.scripts"
  mkdir -p "$out/$profile" "$out/$profile.scripts"
  # archive's --include returns the wrong set in chezmoi 2.74.1, so
  # split the full archive by the script list managed reports.
  cz archive --format tar | untar "$out/$profile"
  cz managed --include scripts --path-style all --format json >"$work/$profile.scripts.json"
  "$jq" -r 'keys[]' "$work/$profile.scripts.json" | while IFS= read -r script; do
    [ -e "$out/$profile/$script" ] || continue
    mkdir -p "$(dirname "$out/$profile.scripts/$script")"
    mv "$out/$profile/$script" "$out/$profile.scripts/$script"
  done
  rmdir "$out/$profile/.chezmoiscripts" 2>/dev/null || true

  python3 -I "$here/manifest.py" "$out/$profile" >"$work/golden/$profile.manifest"
  python3 -I "$here/manifest.py" "$out/$profile.scripts" "$work/$profile.scripts.json" >"$work/golden/$profile.scripts"
  printf '%s targets=%s scripts=%s\n' "$profile" \
    "$(wc -l <"$work/golden/$profile.manifest" | tr -d ' ')" "$(wc -l <"$work/golden/$profile.scripts" | tr -d ' ')"
done

# Goldens change only after every profile rendered, each by a rename.
status=0
for file in "$work"/golden/*; do
  name=${file##*/}
  if [ -n "$check" ]; then
    cmp -s "$file" "$here/golden/$name" || { echo "differs: golden/$name" >&2; status=1; }
  else
    cp "$file" "$here/golden/.$name.new"
    mv -f "$here/golden/.$name.new" "$here/golden/$name"
  fi
done
exit $status
