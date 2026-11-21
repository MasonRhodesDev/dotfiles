{ pkgs }:
pkgs.writeShellScriptBin "keep-original" ''
  set -euo pipefail
  file=''${1:?keep-original needs a file}
  state=''${DOTFILES_STATE:?keep-original is run by dotfiles-root-apply}
  exists() { [ -e "$1" ] || [ -L "$1" ]; }

  if ! exists "$file"; then
    grep -qxF "$file" "$state/made" 2>/dev/null || echo "$file" >> "$state/made"
    exit 0
  fi
  ! grep -qxF "$file" "$state/made" 2>/dev/null || exit 0
  if [ -L "$file" ]; then
    copy=$state/links$file
    exists "$copy" || { mkdir -p "$(dirname "$copy")" && cp -P --preserve=ownership,timestamps "$file" "$copy"; }
  else
    copy=$file.pre-nix
    exists "$copy" || {
      (umask 0111 && cp --preserve=ownership,timestamps "$file" "$copy.new") && mv -f "$copy.new" "$copy" || { rm -f "$copy.new"; exit 1; }
    }
  fi
''
