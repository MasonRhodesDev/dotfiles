say() { echo "dotfiles-lib-guard: $*" >&2; }

command -v pacman > /dev/null 2>&1 || exit 0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

protected() {
  pacman -Qq > "$work/installed"
  {
    { pacman -Qmq || true; } | sed 's/$/\tforeign/'
    for repo in "${repos[@]}"; do
      { pacman -Sl "$repo" 2> /dev/null || true; } | awk -v repo="$repo" '{ print $2 "\t" repo }'
    done
  } | awk -F '\t' 'NR == FNR { on[$1] = 1; next } on[$1] && !seen[$1]++' "$work/installed" - > "$work/protected"
}

scan() {
  local mode=$1
  cut -f 1 "$work/protected" | xargs pacman -Ql | sed 's/ /\t/' \
    | awk -F '\t' '$2 !~ /\/$/ && $2 !~ /^\/usr\/(lib|src)\/debug\//' > "$work/owners"
  ldconfig -p > "$work/cache" 2> /dev/null || : > "$work/cache"
  { cut -f 2 "$work/owners" | xargs -d '\n' readelf -h -d -W /dev/null 2> /dev/null || true; } \
    | gawk -v mode="$mode" -v cachefile="$work/cache" -v ownersfile="$work/owners" -v droppedfile="$work/dropped" -f "$resolver"
}

needs_of_archive() {
  local archive=$1 dir
  dir=$(mktemp -d -p "$work")
  bsdtar -xf "$archive" -C "$dir" 2> /dev/null || return 1
  { find "$dir" -type f -print0 | xargs -0 readelf -d -W /dev/null 2> /dev/null || true; } \
    | sed -n 's/.*(NEEDED).*\[\(.*\)\]$/\1/p' | sort -u
}

new_archive() {
  local location dir
  location=$(pacman -Sddp --print-format %l "$1" 2> /dev/null | tail -n 1) || return 1
  case $location in
    file://*) [ -f "${location#file://}" ] && echo "${location#file://}" && return 0 ;;
  esac
  while IFS= read -r dir; do
    if [ -f "$dir/${location##*/}" ]; then echo "$dir/${location##*/}"; return 0; fi
  done < <(pacman-conf CacheDir 2> /dev/null)
  return 1
}

hook() {
  local pkg file needed path archive kept
  : > "$work/dropped"
  : > "$work/upgrading"
  while IFS= read -r line; do
    case $line in
      */*) echo "/${line#/}" >> "$work/dropped" ;;
      ?*) echo "$line" >> "$work/upgrading" ;;
    esac
  done
  [ -s "$work/dropped" ] || return 0
  protected
  [ -s "$work/protected" ] || return 0
  scan dropped > "$work/found"
  : > "$work/offending"
  while IFS=$'\t' read -r pkg file needed path; do
    if grep -qxF -- "$pkg"$'\t'"$path" "$work/owners"; then continue; fi
    if grep -qxF -- "$pkg" "$work/upgrading"; then
      if [ ! -e "$work/new-$pkg" ]; then
        if archive=$(new_archive "$pkg") && needs_of_archive "$archive" > "$work/new-$pkg.list"; then
          mv "$work/new-$pkg.list" "$work/new-$pkg"
        else
          echo "?" > "$work/new-$pkg"
        fi
      fi
      if ! grep -qxF "?" "$work/new-$pkg" && ! grep -qxF -- "$needed" "$work/new-$pkg"; then continue; fi
    fi
    printf '%s\t%s\t%s\t%s\n' "$pkg" "$file" "$needed" "$path" >> "$work/offending"
  done < "$work/found"
  [ -s "$work/offending" ] || return 0

  say "this transaction takes away shared libraries that packages built outside the distro repositories still load:"
  while IFS=$'\t' read -r needed path; do
    kept=$(pacman -Qqo "$path" 2> /dev/null | head -n 1 || true)
    awk -F '\t' -v needed="$needed" -v path="$path" '$3 == needed && $4 == path { files[$1]++; if (!($1 in first)) first[$1] = $2 }
      END { for (p in files) printf "%s\t%s\t%d\n", p, first[p], files[p] }' "$work/offending" | sort \
      | while IFS=$'\t' read -r pkg file count; do
        say "  $needed${kept:+ (from $kept)} is loaded by $pkg ($(awk -F '\t' -v p="$pkg" '$1 == p { print $2 }' "$work/protected")): $file$([ "$count" = 1 ] || echo " and $((count - 1)) more")"
      done
  done < <(cut -f 3,4 "$work/offending" | sort -u)
  cut -f 1 "$work/offending" | awk '!seen[$0]++' | paste -sd ' ' > "$work/rebuild"
  return 10
}

unresolved() {
  protected
  [ -s "$work/protected" ] || return 0
  scan unresolved | awk -F '\t' '
    { key = $1 SUBSEP $3; if (!(key in files)) { order[++n] = key; first[key] = $2 } files[key]++ }
    END { for (i = 1; i <= n; i++) { split(order[i], k, SUBSEP); print k[1] "\t" k[2] "\t" first[order[i]] "\t" files[order[i]] } }' \
    | sort | while IFS=$'\t' read -r pkg needed file count; do
      echo "$pkg ($(awk -F '\t' -v p="$pkg" '$1 == p { print $2 }' "$work/protected")) cannot load $needed: $file$([ "$count" = 1 ] || echo " and $((count - 1)) more") need it. Rebuild $pkg."
    done
}

case ${1:-} in
  hook)
    set +e
    (set -e; hook)
    status=$?
    set -e
    case $status in
      0) ;;
      10)
        if [ "${DOTFILES_LIB_GUARD:-}" = off ]; then
          say "DOTFILES_LIB_GUARD=off, so the transaction goes ahead. Rebuild these afterwards: $(cat "$work/rebuild")"
        else
          say "rebuild these against the new libraries, or upgrade them in the same transaction: $(cat "$work/rebuild")"
          say "to go ahead anyway, run the same pacman command as: sudo DOTFILES_LIB_GUARD=off pacman ..."
          exit 1
        fi
        ;;
      *) say "the check itself failed (exit $status), so it does not hold the transaction back" ;;
    esac
    ;;
  unresolved) unresolved ;;
  *) say "usage: dotfiles-lib-guard hook|unresolved"; exit 2 ;;
esac
