{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  json = pkgs.formats.json { };
  word = types.strMatching "[^\t\n]*";

  file = {
    options = {
      strategy = mkOption { type = types.enum [ "overwrite" "seed" "merge-json" "merge-ini" ]; };
      text = mkOption { type = types.nullOr types.lines; default = null; };
      source = mkOption { type = types.nullOr types.path; default = null; };
      json = mkOption {
        type = types.nullOr json.type;
        default = null;
        description = "Content as data. Several solutions can each set keys of the same file.";
      };
      ini = mkOption {
        type = types.nullOr (types.attrsOf (types.attrsOf word));
        default = null;
        example = { "Default Applications"."x-scheme-handler/magnet" = "qbt-magnet.desktop"; };
        description = "merge-ini only: keys by section that every switch sets, leaving every other line as it is, and removing a line it set before only while the line still holds what it set. text or source is the file it starts from when there is none. Several solutions can each set keys of the same file.";
      };
      adopt = mkOption {
        type = types.nullOr json.type;
        default = null;
        description = "merge-json only: content an earlier manager wrote that this flake now owns, removed from the file unless json declares it.";
      };
      mode = mkOption { type = types.str; default = "0644"; };
      whenPresent = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = ".codex";
        description = "A path under the home directory. The file is written, and planned, only while that path exists, as an app's own directory does once the app is installed.";
      };
    };
  };

  contentOf = path: f:
    if f.source != null then f.source
    else if f.json != null then json.generate (baseNameOf path) f.json
    else if f.text != null then pkgs.writeText (baseNameOf path) f.text
    else "-";

  keysOf = path: f:
    if f.ini == null then "-"
    else pkgs.writeText "keys-${baseNameOf path}" (lib.concatStrings (lib.mapAttrsToList
      (section: lib.concatMapAttrsStringSep "" (key: value: "${section}\t${key}\t${value}\n"))
      f.ini));

  iniNames = f: lib.all (name: builtins.match "[^]\t\n=[]+" name != null)
    (lib.concatLists (lib.mapAttrsToList (section: keys: [ section ] ++ lib.attrNames keys) f.ini));

  valid = f:
    if f.strategy == "merge-ini" then
      f.json == null && f.adopt == null && lib.count (v: v != null) [ f.text f.source ] <= 1
      && (f.ini != null || given f == 1) && (f.ini != null -> iniNames f)
    else given f == 1 && f.ini == null && (f.strategy == "merge-json" -> f.json != null) && (f.adopt != null -> f.strategy == "merge-json");

  given = f: lib.count (v: v != null) [ f.text f.source f.json ];

  adoptedOf = path: f: if f.adopt == null then "-" else json.generate "adopted-${baseNameOf path}" f.adopt;

  presentOf = f: lib.escapeShellArg (if f.whenPresent == null then "-" else f.whenPresent);

  union = ''
    def union($a; $b):
      if ($a | type) == "object" and ($b | type) == "object" then
        reduce ($b | keys_unsorted[]) as $k ($a; .[$k] = union($a[$k]; $b[$k]))
      elif ($a | type) == "array" and ($b | type) == "array" then
        $a + [ $b[] as $e | select(($a | index([$e])) == null) | $e ]
      elif $a == null then $b
      else $a end;
  '';

  merge = pkgs.writeText "merge.jq" ''
    ${union}
    def once: reduce .[] as $e ([]; if index([$e]) == null then . + [$e] else . end);
    def merge($live; $last; $now):
      if ($now | type) == "object" and ($live | type) == "object" then
        (if ($last | type) == "object" then $last else {} end) as $wrote
        | reduce ($wrote | keys_unsorted[] | select(. as $k | ($now | has($k) | not) and ($live | has($k)))) as $k ($live;
            (if (.[$k] | type) == "object" and ($wrote[$k] | type) == "object" then merge(.[$k]; $wrote[$k]; {})
             elif (.[$k] | type) == "array" and ($wrote[$k] | type) == "array" then merge(.[$k]; $wrote[$k]; [])
             else null end) as $left
            | if $left == null or $left == {} or $left == [] then del(.[$k]) else .[$k] = $left end)
        | reduce ($now | keys_unsorted[]) as $k (.; .[$k] = merge(.[$k]; $wrote[$k]; $now[$k]))
      elif ($now | type) == "array" and ($live | type) == "array" then
        (if ($last | type) == "array" then $last else [] end) as $wrote
        | ($now | once) as $now
        | reduce ($live[] | select(. as $e | ($wrote | index([$e])) == null or ($now | index([$e])) != null)) as $e ([];
            if ($now | index([$e])) != null and index([$e]) != null then . else . + [$e] end)
        | . + [ $now[] as $e | select(index([$e]) == null) | $e ]
      elif ($now | type) == "object" then merge({}; $last; $now)
      elif ($now | type) == "array" then merge([]; $last; $now)
      else $now end;
    merge($live[0]; union(($last[0] // null); ($adopt[0] // null)); $now[0])
  '';

  delta = pkgs.writeText "delta.jq" ''
    def at($p): if $p == [] then "the top level" else $p | map(tostring) | join(".") end;
    def delta($a; $b; $p):
      if ($a | type) == "object" and ($b | type) == "object" then
        [ $a | keys_unsorted[] | select(. as $k | $b | has($k) | not) | "removes \(at($p + [.])): \($a[.] | tojson)" ]
        + [ $b | keys_unsorted[] | select(. as $k | $a | has($k) | not) | "adds \(at($p + [.])): \($b[.] | tojson)" ]
        + ([ $a | keys_unsorted[] | select(. as $k | $b | has($k)) | . as $k | delta($a[$k]; $b[$k]; $p + [$k]) ] | add // [])
      elif ($a | type) == "array" and ($b | type) == "array" then
        [ $a[] | select(. as $e | ($b | index([$e])) == null) | "removes from \(at($p)): \(tojson)" ]
        + [ $b[] | select(. as $e | ($a | index([$e])) == null) | "adds to \(at($p)): \(tojson)" ]
      elif $a == $b then []
      else [ "sets \(at($p)) to \($b | tojson)" ] end;
    delta($before[0]; $after[0]; [])[]
  '';

  iniMerged = live: src: keys: last: ''
    ${pkgs.gawk}/bin/awk -v keys="$([[ ''$${keys} != - ]] && echo "''$${keys}" || echo /dev/null)" \
      -v last="$([[ -s ''$${last} ]] && echo "''$${last}" || echo /dev/null)" -f ${./merge-ini.awk} \
      "$(if [[ -e ''$${live} ]]; then echo "''$${live}"; elif [[ ''$${src} != - ]]; then echo "''$${src}"; else echo /dev/null; fi)"'';

  merged = live: src: last: adopted: ''
    ${pkgs.jq}/bin/jq -n --slurpfile live "$([[ -s ''$${live} ]] && echo "''$${live}" || echo /dev/null)" --slurpfile now "''$${src}" \
      --slurpfile last "$([[ -s ''$${last} ]] && echo "''$${last}" || echo /dev/null)" \
      --slurpfile adopt "$([[ ''$${adopted} != - ]] && echo "''$${adopted}" || echo /dev/null)" -f ${merge}'';

  plan = pkgs.writeShellScript "dotfiles-mutable-plan" ''
    plan() {
      local strategy=$1 src=$2 rel=$3 adopted=$4 present=$5 keys=$6 dst=$HOME/$3 last after
      last=''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/mutable/$3
      [[ $present == - || -e $HOME/$present ]] || return 0
      case $strategy in
        seed) [[ -e $dst ]] || echo "  ~/$rel: written, it does not exist yet" ;;
        overwrite)
          if [[ ! -e $dst ]]; then echo "  ~/$rel: written, it does not exist yet"
          elif ! cmp -s "$src" "$dst"; then echo "  ~/$rel: replaced by the flake's copy"; fi ;;
        merge-json)
          if ! after=$(${merged "dst" "src" "last" "adopted"}); then
            echo "  ~/$rel: left as it is, it is not valid JSON"
          elif [[ ! -e $dst ]]; then
            echo "  ~/$rel: written, it does not exist yet"
          else
            ${pkgs.jq}/bin/jq -rn --slurpfile before "$dst" --slurpfile after /dev/stdin -f ${delta} <<< "$after" \
              | sed "s|^|  ~/$rel: |"
          fi ;;
        merge-ini)
          if [[ ! -e $dst ]]; then
            echo "  ~/$rel: written, it does not exist yet"
          else
            ${pkgs.diffutils}/bin/diff "$dst" <(${iniMerged "dst" "src" "keys" "last"}) \
              | sed -n "s|^< |  ~/$rel: removes the line |p; s|^> |  ~/$rel: adds the line |p"
          fi ;;
      esac
    }
    {
    ${lib.concatStrings (lib.mapAttrsToList
      (path: f: "plan ${f.strategy} ${contentOf path f} ${lib.escapeShellArg path} ${adoptedOf path f} ${presentOf f} ${keysOf path f}\n")
      config.dotfiles.mutable)}
    } | grep . || echo "  none"
  '';
in
{
  options.dotfiles.mutable = mkOption {
    type = types.attrsOf (types.submodule file);
    default = { };
    description = "Files written at activation instead of linked from the store, keyed by path under the home directory.";
  };

  config = {
    assertions = lib.mapAttrsToList
      (path: f: {
        assertion = valid f;
        message = "dotfiles.mutable.\"${path}\": set exactly one of text, source and json. merge-json needs json, and only merge-json adopts. merge-ini takes ini, with section and key names free of tabs, newlines, brackets and =, and at most one of text and source as the file it starts from.";
      })
      config.dotfiles.mutable;

    home.file.".local/share/dotfiles/mutable-plan" = { source = plan; executable = true; };

    home.activation.dotfilesMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      mutable() {
        local strategy=$1 mode=$2 src=$3 dst=$HOME/$4 adopted=$5 present=$6 keys=$7 tmp last
        last=''${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/mutable/$4
        [[ $present == - || -e $HOME/$present ]] || return 0
        if [[ -v DRY_RUN ]]; then echo "would $strategy $dst"; return 0; fi
        mkdir -p "$(dirname "$dst")"
        [[ $strategy == seed && -e $dst ]] && return 0
        tmp=$(mktemp "$dst.XXXXXX")
        if [[ $strategy == merge-json ]]; then
          if ! ${merged "dst" "src" "last" "adopted"} > "$tmp"; then
            rm -f "$tmp"
            errorEcho "$dst is not valid JSON, left as it is"
            return 0
          fi
        elif [[ $strategy == merge-ini ]]; then
          ${iniMerged "dst" "src" "keys" "last"} > "$tmp"
        else
          cat "$src" > "$tmp"
        fi
        if ! cmp -s "$tmp" "$dst"; then
          if [[ -e $dst && ! -e $dst.pre-nix ]]; then cp -pL "$dst" "$dst.pre-nix"; fi
          chmod "$mode" "$tmp"
          mv -f "$tmp" "$dst"
        else
          rm -f "$tmp"
        fi
        if [[ $strategy == merge-json ]]; then install -D -m 0644 "$src" "$last"; fi
        if [[ $strategy == merge-ini && $keys != - ]]; then install -D -m 0644 "$keys" "$last"; fi
        if [[ $strategy == merge-ini && $keys == - ]]; then rm -f "$last"; fi
      }
      ${lib.concatStrings (lib.mapAttrsToList
        (path: f: "mutable ${f.strategy} ${f.mode} ${contentOf path f} ${lib.escapeShellArg path} ${adoptedOf path f} ${presentOf f} ${keysOf path f}\n")
        config.dotfiles.mutable)}
    '';
  };
}
