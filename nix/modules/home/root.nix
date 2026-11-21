{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  families = [ "arch" "fedora" ];

  httpsUrl = types.strMatching "https://[^[:space:]]+";

  repository = family: {
    options = lib.optionalAttrs (family == "fedora") {
      metadataSigned = mkOption {
        type = types.bool;
        default = false;
        description = "The repository signs its metadata with the same key, so dnf checks that signature too (repo_gpgcheck). Off for a repository that publishes none, where the check would fail every install.";
      };
    } // {
      url = mkOption {
        type = httpsUrl;
        description = "Arch: the repository's Server. Fedora: its baseurl.";
      };
      key.url = mkOption {
        type = httpsUrl;
        description = "Where the repository's signing key is fetched from.";
      };
      key.fingerprint = mkOption {
        type = types.strMatching "[0-9A-F]{40}";
        description = "The signing key's primary fingerprint. A key file holding anything but exactly this key is refused.";
      };
    };
  };

  step = {
    options = {
      repositories = lib.genAttrs families (family: mkOption {
        type = types.attrsOf (types.submodule (repository family));
        default = { };
        description = "Package repositories by name (${family}: ${if family == "arch" then "the pacman.conf section" else "the dnf repository id"}), set up before any package is installed.";
      });
      distroRepositories.arch = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "multilib" ];
        description = "Arch: repositories the distro itself serves from its mirror list but ships switched off. Each gets its pacman.conf section before any package is installed, and no key.";
      };
      distros = mkOption {
        type = types.listOf (types.enum families);
        default = families;
        description = "Distro families the step applies to.";
      };
      packages = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        example = { arch = [ "tailscale" ]; fedora = [ "tailscale" ]; };
        description = "Distro package names by family.";
      };
      files = mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            text = mkOption { type = types.lines; };
            mode = mkOption { type = types.str; default = "0644"; };
            reload = mkOption {
              type = types.lines;
              default = "";
              description = "Idempotent shell that makes whatever reads the file read it again. Run when the file's content changes: after it is written, and after it is removed or put back because no step declares it any more. Files with the same command share one run of it, and a run that fails is repeated by the next switch.";
            };
          };
        });
        default = { };
        description = "Files by absolute path.";
      };
      units = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "System units to enable and start.";
      };
      script = mkOption {
        type = types.lines;
        default = "";
        description = "Idempotent shell, run as root after files and units, with DISTRO, ID and VERSION_ID in its environment.";
      };
    };
  };

  keepOriginal = import ./keep-original.nix { inherit pkgs; };

  steps = config.dotfiles.root;
  on = family: lib.filterAttrs (_: s: lib.elem family s.distros) steps;
  everywhere = lib.filterAttrs (_: s: lib.all (f: lib.elem f s.distros) families) steps;
  perFamily = render: ''
    case $DISTRO in
    ${lib.concatMapStrings (family: "${family})\n${render (on family) family}\n;;\n") families}*)
    ${render everywhere null}
    ;;
    esac
  '';

  header = name:
    if builtins.match "[A-Za-z0-9_.:-]+" name != null && !lib.elem name [ "options" "main" ] then "[${name}]"
    else throw "dotfiles.root: '${name}' cannot name a package repository";

  sections = {
    arch = name: r: ''
      ${header name}
      SigLevel = Required DatabaseRequired
      Server = ${r.url}
    '';
    fedora = name: r: ''
      ${header name}
      name=${name}
      baseurl=${r.url}
      type=rpm-md
      skip_if_unavailable=True
      gpgcheck=1
      gpgkey=file://${fedoraKey name}
      repo_gpgcheck=${if r.metadataSigned then "1" else "0"}
      enabled=1
      enabled_metadata=1
    '';
  };
  distroSection = name: ''
    ${header name}
    Include = /etc/pacman.d/mirrorlist
  '';
  fedoraKey = name: "/etc/pki/rpm-gpg/RPM-GPG-KEY-${lib.replaceStrings [ ":" ] [ "-" ] name}";
  fedoraFile = name: "/etc/yum.repos.d/${lib.optionalString (lib.hasPrefix "copr:" name) "_"}${name}.repo";

  repositories = selected: family:
    let
      text = name: pkgs.writeText "repository-${lib.strings.sanitizeDerivationName name}";
      setup = function: name: "attempt ${lib.escapeShellArgs [ "repository ${name}" function name ]}";
      distro = s: map (name: "${setup "arch_section" name} ${text name (distroSection name)}\n")
        (lib.optionals (family == "arch") s.distroRepositories.arch);
      pinned = s: lib.mapAttrsToList
        (name: r: "${setup "${family}_repository" name} ${text name (sections.${family} name r)} ${lib.escapeShellArgs [ r.key.url r.key.fingerprint ]}${lib.optionalString (family == "fedora") " ${lib.escapeShellArgs [ (fedoraKey name) (fedoraFile name) ]}"}\n")
        s.repositories.${family};
    in
    lib.optionalString (family != null)
      (lib.concatStrings (lib.unique (lib.concatMap distro (lib.attrValues selected) ++ lib.concatMap pinned (lib.attrValues selected))));

  packages = selected: family:
    if family == null then
      lib.optionalString (lib.any (s: s.packages != { }) (lib.attrValues selected))
        "say \"no package manager for distro '$ID', package steps skipped\""
    else
      let
        wanted = lib.filterAttrs (_: names: names != [ ]) (lib.mapAttrs (_: s: s.packages.${family} or [ ]) selected);
        names = lib.unique (lib.concatLists (lib.attrValues wanted));
      in
      lib.optionalString (names != [ ]) ''
        if ! install_together ${lib.escapeShellArgs (lib.attrNames wanted ++ [ "--" ] ++ names)}; then
          ${lib.concatStrings (lib.mapAttrsToList (id: ns: "step_packages ${lib.escapeShellArgs ([ id ] ++ ns)}\n") wanted)}
        fi
      '';

  files = selected: _:
    lib.concatStrings (lib.mapAttrsToList
      (id: s: lib.concatStrings (lib.mapAttrsToList
        (dest: f: "put ${lib.escapeShellArg id} ${f.mode} ${pkgs.writeText (baseNameOf dest) f.text} ${lib.escapeShellArg dest} ${if f.reload == "" then "-" else pkgs.writeText "reload-${baseNameOf dest}" f.reload}\n")
        s.files))
      selected);

  units = selected: _:
    lib.concatStrings (lib.mapAttrsToList
      (id: s: lib.concatMapStrings (unit: "enable_unit ${lib.escapeShellArgs [ id unit ]}\n") s.units)
      selected);

  scripts = selected: _:
    lib.concatStrings (lib.mapAttrsToList
      (id: s: lib.optionalString (s.script != "") ''
        if ready ${lib.escapeShellArg id}; then
          echo ${lib.escapeShellArg "root step: ${id}"}
          attempt ${lib.escapeShellArg "script ${id}"} ${pkgs.runtimeShell} -euo pipefail ${pkgs.writeText "root-step-${id}" s.script}
        fi
      '')
      selected);

  program = scratch:
    let root = lib.optionalString (scratch != null) scratch; in
    pkgs.writeShellScriptBin "dotfiles-root-apply" ''
      set -euo pipefail
      ${lib.optionalString (scratch == null) ''[ "$(id -u)" = 0 ] || [ "''${1:-}" = --retiring ] || { echo "dotfiles-root-apply: run as root" >&2; exit 1; }''}

      say() { echo "dotfiles-root-apply: $*" >&2; }
      stop() { say "$*. Not recorded, so the next switch runs it again."; exit 1; }

      state="${root}/var/lib/dotfiles"

      ID= ID_LIKE= VERSION_ID=
      if [ -r "${root}/etc/os-release" ]; then . "${root}/etc/os-release"; fi
      case " $ID $ID_LIKE " in
        *" arch "* | *" archarm "*) DISTRO=arch ;;
        *" fedora "*) DISTRO=fedora ;;
        *) DISTRO=unknown ;;
      esac
      export DISTRO ID VERSION_ID
      shown=''${ID:-not set}
      unknown="distro '$shown' is not arch or fedora"

      if [ "''${1:-}" = --retiring ]; then
        [ "$DISTRO" != unknown ] && [ -e "$state/units" ] || exit 0
        [ -r "$state/units" ] || { say "cannot read $state/units"; exit 1; }
        declared=()
        enable_unit() { declared+=("$2"); }
        ${perFamily units}
        while IFS= read -r unit; do
          [[ " ''${declared[*]} " == *" $unit "* ]] || echo "$unit"
        done < "$state/units"
        exit 0
      fi

      mkdir -p "$state"
      rm -f "$state/applied"
      [ "$DISTRO" != unknown ] || say "$unknown. Running only the steps for every distro"

      failed=()
      attempt() {
        local what=$1
        shift
        if ! "$@"; then
          failed+=("$what")
          say "$what failed, continuing"
        fi
      }

      declare -A skipped=() enabled=() due_now=()
      ready() { [ -z "''${skipped[$1]:-}" ]; }

      fingerprints() {
        local home
        home=$(mktemp -d)
        ${pkgs.gnupg}/bin/gpg --homedir "$home" --batch --show-keys --with-colons "$1" 2>/dev/null \
          | awk -F: '$1 == "pub" { p = 1; next } p && $1 == "fpr" { print $10; p = 0 }'
        rm -rf "$home"
      }
      fetch_key() {
        local url=$1 fingerprint=$2 dest=$3 tmp got
        tmp=$(mktemp -d)
        if ! curl --proto '=https' --proto-redir '=https' --tlsv1.2 --max-time 60 -fsSL "$url" -o "$tmp/key"; then
          say "could not fetch the signing key $url"
          rm -rf "$tmp"
          return 1
        fi
        got=$(fingerprints "$tmp/key")
        if [ "$got" != "$fingerprint" ]; then
          say "the signing key at $url is not the pinned key $fingerprint (it holds: ''${got:-no key}), so it is not trusted"
          rm -rf "$tmp"
          return 1
        fi
        install -D -m 0644 "$tmp/key" "$dest" || { rm -rf "$tmp"; return 1; }
        rm -rf "$tmp"
      }

      exists() { [ -e "$1" ] || [ -L "$1" ]; }
      note() { grep -qxF -- "$2" "$1" 2>/dev/null || echo "$2" >> "$1"; }

      export DOTFILES_STATE="$state" PATH="${keepOriginal}/bin:$PATH"
      keep() { keep-original "$1"; }
      writing() {
        local file=$1
        shift
        keep "$file" && "$@"
      }

      section() {
        [ -e "$2" ] || return 0
        awk -v want="[$1]" '{ l = $0; gsub(/[[:space:]]/, "", l) } l ~ /^\[/ { on = (l == want); next } on && l != "" && l !~ /^#/' "$2"
      }
      same_section() { [ "$(section "$1" "$3")" = "$(tail -n +2 "$2")" ]; }
      defines() { awk -v want="[$1]" '{ gsub(/[[:space:]]/, "") } $0 == want { found = 1 } END { exit !found }' "$2"; }
      set_section() { writing "$3" write_section "$@"; }
      without_section() {
        awk -v want="[$1]" '
          { l = $0; gsub(/[[:space:]]/, "", l) }
          l ~ /^\[/ { on = (l == want) }
          on { next }
          l == "" { blank++; next }
          { for (; blank > 0; blank--) print ""; print }
        ' "$2"
      }
      write_section() {
        local name=$1 src=$2 conf=$3 tmp=$3.dotfiles-new
        if [ -e "$conf" ]; then
          without_section "$name" "$conf" > "$tmp" \
            && { [ ! -s "$tmp" ] || echo >> "$tmp"; } \
            && chmod --reference="$conf" "$tmp"
        else
          install -D -m 0644 /dev/null "$tmp"
        fi && cat "$src" >> "$tmp" && mv -f "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
      }
      remove_section() {
        local name=$1 conf=$2 tmp=$2.dotfiles-new
        without_section "$name" "$conf" > "$tmp" && chmod --reference="$conf" "$tmp" && mv -f "$tmp" "$conf" || { rm -f "$tmp"; return 1; }
      }

      section_sources() {
        awk -v want="[$1]" '
          /^[[:space:]]*\[/ { here = ($0 == want) }
          here && /^[[:space:]]*(Server|Include)[[:space:]]*=/ { gsub(/[[:space:]]/, ""); print }
        ' "$2" 2>/dev/null
      }

      unsynced=()
      arch_section() {
        local name=$1 src=$2 conf="${root}/etc/pacman.conf" db="${root}/var/lib/pacman/sync/$1.db" from
        if ! same_section "$name" "$src" "$conf"; then
          from=$(section_sources "$name" "$conf")
          set_section "$name" "$src" "$conf" || return 1
          echo "configured repository $name in /etc/pacman.conf"
          [ "$from" = "$(section_sources "$name" "$conf")" ] || rm -f "$db" "$db.sig"
        fi
        [ -e "$db" ] || unsynced+=("$name")
      }
      arch_repository() {
        local name=$1 src=$2 url=$3 fingerprint=$4 key
        if ! { same_section "$name" "$src" "${root}/etc/pacman.conf" && pacman-key --list-keys "$fingerprint" > /dev/null 2>&1; }; then
          if ! pacman-key --list-keys "$fingerprint" > /dev/null 2>&1; then
            key=$(mktemp -d)
            if ! { fetch_key "$url" "$fingerprint" "$key/key" && pacman-key --init && pacman-key --add "$key/key"; }; then
              rm -rf "$key"
              return 1
            fi
            rm -rf "$key"
          fi
          pacman-key --lsign-key "$fingerprint" || return 1
        fi
        arch_section "$name" "$src"
      }
      fedora_repository() {
        local name=$1 src=$2 url=$3 fingerprint=$4 key=$5 file=$6 f tmp found=
        for f in "${root}/etc/yum.repos.d"/*.repo; do
          [ -e "$f" ] && defines "$name" "$f" || continue
          if [ -z "$found" ]; then
            found=1
            file=/etc/yum.repos.d/''${f##*/}
          else
            writing "$f" remove_section "$name" "$f" || return 1
            echo "removed a second definition of repository $name from /etc/yum.repos.d/''${f##*/}"
          fi
        done
        if [ "$(fingerprints "${root}$key")" != "$fingerprint" ]; then
          tmp=$(mktemp -d)
          if ! { fetch_key "$url" "$fingerprint" "$tmp/key" && writing "${root}$key" install -D -m 0644 "$tmp/key" "${root}$key"; }; then
            rm -rf "$tmp"
            return 1
          fi
          rm -rf "$tmp"
        fi
        if ! same_section "$name" "$src" "${root}$file"; then
          set_section "$name" "$src" "${root}$file" || return 1
          echo "configured repository $name in $file"
        fi
      }

      touch "$state/made" "$state/files" "$state/kept" "$state/units"
      : > "$state/files.next"
      : > "$state/kept.next"
      : > "$state/units.next"

      unsatisfied() {
        local name status=0
        case $DISTRO in
          arch) LC_ALL=C pacman -T "$@" || status=$? ;;
          fedora) for name; do LC_ALL=C rpm -q --quiet --whatprovides "$name" || echo "$name"; done ;;
        esac
        [ "$status" = 0 ] || [ "$status" = 127 ] || { echo "the local package database could not say which packages are installed (exit $status)" >&2; return 1; }
      }
      install_missing() {
        local wanted names=()
        wanted=$(unsatisfied "$@") || return 1
        [ -n "$wanted" ] || return 0
        mapfile -t names <<< "$wanted"
        case $DISTRO in
          arch) LC_ALL=C pacman -S --needed --noconfirm "''${names[@]}" ;;
          fedora) LC_ALL=C dnf install -y "''${names[@]}" ;;
        esac
      }
      package_manager() {
        local log=$1
        shift
        install_missing "$@" 2>&1 | tee "$log"
      }
      case $DISTRO in
        arch)
          package_failed='^error: (target not found: |failed to (prepare|commit) transaction \((could not satisfy dependencies|conflicting dependencies|conflicting files|invalid or corrupted package|package missing required signature|could not find or read package))'
          gone='^error: failed retrieving file .* : The requested URL returned error: 404'
          upgrade='sudo pacman -Syu'
          ;;
        fedora)
          package_failed='Failed to resolve the transaction|Transaction failed: (Signature verification failed|Rpm transaction check failed|Rpm transaction failed)'
          gone='Status code: 404 for [^[:space:]]+\.rpm([[:space:]]|$)'
          upgrade='sudo dnf upgrade --refresh'
          ;;
      esac
      synced() {
        local wanted conf name status=0
        [ ''${#unsynced[@]} != 0 ] || return 0
        wanted=$(unsatisfied "$@" 2> /dev/null) && [ -n "$wanted" ] || return 0
        echo "dotfiles-root-apply: syncing the package databases of ''${unsynced[*]} only, which have none yet, to install packages (pacman -Sy with a configuration that names no other repository, and no system upgrade)"
        conf=$(mktemp)
        {
          echo "[options]"
          section options "${root}/etc/pacman.conf"
          for name in "''${unsynced[@]}"; do
            printf '\n[%s]\n' "$name"
            section "$name" "${root}/etc/pacman.conf"
          done
        } > "$conf" && LC_ALL=C pacman -Sy --config "$conf" --noconfirm || status=$?
        rm -f "$conf"
        return $status
      }
      install_together() {
        local ids=() log status=0
        while [ "$1" != -- ]; do ids+=("$1"); shift; done
        shift
        if ! synced "$@"; then
          skip_packages "syncing the package databases failed" "''${ids[@]}"
          return 0
        fi
        log=$(mktemp)
        if ! package_manager "$log" "$@"; then
          if grep -Eq "$gone" "$log"; then
            say "the mirror no longer has a package that the package databases name (404), so the databases look stale. Run a full system upgrade ($upgrade) and switch again"
          fi
          if grep -Eq -e "$package_failed" -e "$gone" "$log"; then
            say "installing every package in one call failed. Installing each step's packages on their own"
            status=1
          else
            skip_packages "the package manager failed without naming a package it could not find or install, as it does with no network, a locked database or a full disk" "''${ids[@]}"
          fi
        fi
        rm -f "$log"
        return $status
      }
      skip_packages() {
        local why=$1 id
        shift
        for id; do skipped[$id]=1; done
        failed+=("packages")
        say "$why, so no package was installed and the files, units and script of every step with packages are skipped: $*"
      }
      step_packages() {
        local id=$1
        shift
        if ! package_manager /dev/null "$@"; then
          skipped[$id]=1
          failed+=("packages $id")
          say "packages for $id failed, so its files, units and script are skipped"
        fi
      }
      named() { printf %s "$1" | sha256sum | cut -d ' ' -f 1; }
      remember() {
        local at
        at="$state/reload/$(named "$1")"
        if [ "$2" = - ]; then rm -f "$at"; else cmp -s "$2" "$at" || install -D -m 0644 "$2" "$at"; fi
      }
      due() {
        local at pending
        at="$state/reload/$(named "$1")"
        [ -e "$at" ] || return 0
        pending="$state/pending/$(named "$(cat "$at")")"
        due_now[$pending]=1
        [ -e "$pending" ] || { mkdir -p "$state/pending" && { echo "# $1"; cat "$at"; } > "$pending"; }
      }
      declared_reload() {
        local at
        for at in "$state/reload"/*; do
          [ -e "$at" ] || continue
          [ "$state/pending/$(named "$(cat "$at")")" != "$1" ] || return 0
        done
        return 1
      }
      run_reloads() {
        local command file
        for command in "$state/pending"/*; do
          [ -e "$command" ] || continue
          file=$(head -n 1 "$command")
          file=''${file#"# "}
          if [ -z "''${due_now[$command]:-}" ] && ! declared_reload "$command"; then
            rm -f "$command"
            echo "dropped the pending reload for $file: no step declares it any more"
          elif ${pkgs.runtimeShell} -euo pipefail "$command"; then
            rm -f "$command"
            echo "reloaded for $file"
          else
            failed+=("reload for $file")
            say "the reload for $file failed, continuing"
          fi
        done
      }
      in_place() { cmp -s "$2" "$3" && [ "$(stat -L -c %a "$3")" = "$(printf %o "$((8#$1))")" ]; }
      kept() { awk -v path="$1" '{ line = $0; sub(/^([0-7]+|link) /, "") } $0 == path { print line; found = 1; exit } END { exit !found }' "$state/kept"; }
      put() {
        local id=$1 mode=$2 src=$3 dest=$4 reload=$5 line
        if ! ready "$id"; then
          if grep -qxF "$dest" "$state/files"; then note "$state/files.next" "$dest"; fi
          if line=$(kept "$dest"); then note "$state/kept.next" "$line"; fi
          return 0
        fi
        if line=$(kept "$dest"); then
          note "$state/kept.next" "$line"
        elif grep -qxF "$dest" "$state/files"; then
          note "$state/files.next" "$dest"
        elif ! exists "${root}$dest"; then
          note "$state/files" "$dest"
          note "$state/files.next" "$dest"
        elif ! in_place "$mode" "$src" "${root}$dest"; then
          if [ -L "${root}$dest" ]; then line="link $dest"; else line="$(stat -c %a "${root}$dest") $dest"; fi
          keep "${root}$dest" || stop "could not keep a copy of $dest, stopped before units and scripts"
          note "$state/kept" "$line"
          note "$state/kept.next" "$line"
        fi
        remember "$dest" "$reload"
        if ! in_place "$mode" "$src" "${root}$dest"; then
          due "$dest"
          install -D -m "$mode" "$src" "${root}$dest" || stop "could not write $dest, stopped before units and scripts"
          echo "installed $dest"
        fi
      }
      enable_and_record() { systemctl enable --now "$1" && note "$state/units" "$1"; }
      enable_unit() {
        local id=$1 unit=$2
        note "$state/units.next" "$unit"
        if ready "$id" && [ -z "''${enabled[$unit]:-}" ]; then
          enabled[$unit]=1
          attempt "enable $unit" enable_and_record "$unit"
        fi
      }
      retire_unit() {
        systemctl disable --now "$1" || return 1
        grep -vxF -- "$1" "$state/units" > "$state/units.kept" || true
        mv -f "$state/units.kept" "$state/units"
        echo "disabled and stopped $1"
      }

      ${perFamily repositories}
      ${perFamily packages}
      ${perFamily files}
      if [ "$DISTRO" != unknown ]; then
        while IFS= read -r old; do
          if ! grep -qxF "$old" "$state/files.next"; then
            due "$old"
            rm -f "${root}$old"
            remember "$old" -
            echo "removed $old"
          fi
        done < "$state/files"
        mv -f "$state/files.next" "$state/files"
        while read -r mode old; do
          if ! grep -qxF "$mode $old" "$state/kept.next"; then
            if [ "$mode" = link ]; then copy="$state/links${root}$old"; else copy="${root}$old.pre-nix"; fi
            if exists "$copy"; then
              due "$old"
              { [ "$mode" = link ] || chmod "$mode" "$copy"; } && mv -fT "$copy" "${root}$old" || stop "could not put $old back from its copy"
              remember "$old" -
              echo "restored $old"
            else
              echo "left $old as it is: the copy of what was there before is gone"
            fi
          fi
        done < "$state/kept"
        mv -f "$state/kept.next" "$state/kept"
      else
        rm -f "$state/files.next" "$state/kept.next"
      fi
      run_reloads
      ${perFamily units}
      if [ "$DISTRO" != unknown ]; then
        while IFS= read -r unit; do
          grep -qxF -- "$unit" "$state/units.next" || attempt "disable $unit" retire_unit "$unit"
        done < <(cat "$state/units")
      fi
      rm -f "$state/units.next"
      ${perFamily scripts}
      [ ''${#failed[@]} = 0 ] || stop "failed: ''${failed[*]}"
      [ "$DISTRO" != unknown ] || stop "$unknown, so only the steps for every distro ran and no file was removed"
      ln -sfn "$(readlink -f "$0")" "$state/applied"
    '';
  runner = program null;
in
{
  options.dotfiles.root = mkOption {
    type = types.attrsOf (types.submodule step);
    default = { };
    description = "Root steps by solution id. Filled from each solution's linux.root part.";
  };

  options.dotfiles.rootApply = mkOption {
    type = types.package;
    readOnly = true;
    description = "The dotfiles-root-apply program built from dotfiles.root.";
  };

  options.dotfiles.rootApplyScratch = mkOption {
    type = types.package;
    readOnly = true;
    internal = true;
    description = "The same program against the scratch root that DOTFILES_ROOT_PREFIX names, with no uid check. For checks/root-apply.nix.";
  };

  config = lib.mkMerge [
    { dotfiles.rootApply = runner; dotfiles.rootApplyScratch = program "$DOTFILES_ROOT_PREFIX"; }
    (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && steps != { }) {
      home.packages = [ runner ];
      home.activation.dotfilesRootPending = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ "$(readlink /var/lib/dotfiles/applied 2>/dev/null)" != ${runner}/bin/dotfiles-root-apply ]; then
          warnEcho "root steps changed and were not applied. Run: sudo ${runner}/bin/dotfiles-root-apply"
        fi
      '';
    })
  ];
}
