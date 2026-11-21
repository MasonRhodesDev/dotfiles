{ lib, pkgs, evalHome }:
let
  built = steps: (evalHome { modules = [{ dotfiles.root = steps; }]; }).config.dotfiles;
  program = steps: "${(built steps).rootApplyScratch}/bin/dotfiles-root-apply";

  net = {
    packages = { arch = [ "tailscale" "jq" ]; fedora = [ "tailscale" "dnf-only" ]; };
    files."/etc/net.conf".text = "net\n";
    units = [ "tailscaled.service" ];
    script = ''
      mkdir -p "$DOTFILES_ROOT_PREFIX/etc/net.d"
      echo "$DISTRO $ID $VERSION_ID" > "$DOTFILES_ROOT_PREFIX/etc/net.d/env"
    '';
  };
  pinned = "8121421220927ACADF33B6D76639606D316BA178";
  pinnedSubkey = "784896BD02501786976F09762F81FBAC450DB59C";
  copr = "copr:copr.example.invalid:fixture:hyprrepo";
  hypr = {
    repositories = {
      arch.hyprrepo = { url = "https://repo.example.invalid/$arch"; key = { url = "https://keys.example.invalid/pinned.asc"; fingerprint = pinned; }; };
      fedora.${copr} = { url = "https://repo.example.invalid/fedora-$releasever-$basearch/"; key = { url = "https://keys.example.invalid/pinned.asc"; fingerprint = pinned; }; };
    };
    packages = { arch = [ "hypr-only" ]; fedora = [ "hypr-only" ]; };
    files."/etc/hypr.conf".text = "hypr\n";
    units = [ "hypr.service" "shared.service" ];
    script = ''touch "$DOTFILES_ROOT_PREFIX/etc/hypr-ran"'';
  };
  lib32 = {
    distroRepositories.arch = [ "multilib" ];
    packages.arch = [ "multilib-only" ];
    files."/etc/lib32.conf".text = "lib32\n";
  };
  gaming = {
    packages = { arch = [ "hypr-gaming" ]; fedora = [ "hypr-gaming" ]; };
    files."/etc/gaming.conf".text = "gaming\n";
  };
  archOnly = {
    distros = [ "arch" ];
    files."/etc/arch-only.conf" = { text = "arch\n"; mode = "0600"; };
  };

  lock = text: { files."/etc/pam.d/lock".text = text; };
  hook = { files."/etc/hooks.d/60-hook" = { text = "#!/bin/sh\necho ours\n"; mode = "0755"; }; };

  both = { inherit net hypr; arch-only = archOnly; };
  withLock = program { lock = lock "ours\n"; inherit hook; arch-only = archOnly; };
  withLockBlocked = program { lock = lock "ours\n" // { packages.arch = [ "broken-package" ]; }; inherit hook; arch-only = archOnly; };
  withLockChanged = program { lock = lock "ours, changed\n"; inherit hook; arch-only = archOnly // { files."/etc/arch-only.conf".text = "arch, changed\n"; }; };
  reloading = text: {
    drop-ins.files = {
      "/etc/units.d/a.conf" = { text = "a\n"; reload = "systemctl daemon-reload"; };
      "/etc/units.d/b.conf" = { text = "b\n"; reload = "systemctl daemon-reload"; };
    };
    powersave.files."/etc/reader.d/powersave.conf" = {
      inherit text;
      reload = ''
        { cat "$DOTFILES_ROOT_PREFIX/etc/reader.d/powersave.conf" 2>/dev/null || echo nothing; } >> "$FAKE/reader-read"
        echo "$DISTRO" > "$FAKE/reader-distro"
        [ ! -e "$FAKE/reader-down" ]
      '';
    };
    arch-only = archOnly;
  };
  withReloads = program (reloading "one\n");
  withReloadsChanged = program (reloading "two\n");
  editing = program {
    edits.script = ''
      conf=$DOTFILES_ROOT_PREFIX/etc/distro.conf
      if ! grep -qx "Key = ours" "$conf"; then
        keep-original "$conf"
        sed -i "s/^Key = .*/Key = ours/" "$conf"
      fi
      own=$DOTFILES_ROOT_PREFIX/etc/own.conf
      want=$(cat "$DOTFILES_ROOT_PREFIX/etc/want")
      if [ "$(cat "$own" 2>/dev/null)" != "$want" ]; then
        keep-original "$own"
        echo "$want" > "$own"
      fi
    '';
  };
  lockTwice = program { one = lock "ours\n"; two = lock "ours\n"; inherit hook; arch-only = archOnly; };
  converging = program both;
  withoutArchOnly = program { inherit net hypr; };
  onlyArchOnly = program { arch-only = archOnly; };
  borrowing = program { inherit gaming hypr; };
  borrowingRetried = program { inherit gaming hypr; blocked.packages.arch = [ "broken-package" ]; };
  withLib32 = program { inherit net hypr lib32; };
  onlyLib32 = program { inherit lib32; };

  failing = program {
    broken = {
      units = [ "missing.service" ];
      script = "echo boom >&2; exit 3";
    };
    later = {
      units = [ "tailscaled.service" ];
      script = ''touch "$DOTFILES_ROOT_PREFIX/etc/later-ran"'';
    };
  };

  subkeyPinned = program {
    hypr = hypr // { repositories.arch.hyprrepo = hypr.repositories.arch.hyprrepo // { key = { url = "https://keys.example.invalid/pinned.asc"; fingerprint = pinnedSubkey; }; }; };
  };

  vendor = program {
    vendor.repositories.fedora.vendorrepo = { url = "https://repo.example.invalid/vendor/"; key = { url = "https://keys.example.invalid/pinned.asc"; fingerprint = pinned; }; };
  };

  metadata = program {
    vendor.repositories.fedora = {
      signedrepo = { url = "https://repo.example.invalid/signed/"; inherit key; metadataSigned = true; };
      plainrepo = { url = "https://repo.example.invalid/plain/"; inherit key; };
    };
  };

  key = { url = "https://keys.example.invalid/pinned.asc"; fingerprint = pinned; };
  evaluates = step: (builtins.tryEval (program { declared = step; })).success;
  declarations = lib.mapAttrs (_: c: { inherit (c) want; step.repositories.arch.declared = c.repository; }) urls // {
    "a distro repository is accepted" = { want = true; step.distroRepositories.arch = [ "multilib" ]; };
    "a distro repository named for pacman's own options section is refused" = { want = false; step.distroRepositories.arch = [ "options" ]; };
    "a distro repository whose name closes the header is refused" = { want = false; step.distroRepositories.arch = [ "multilib]\n[options" ]; };
    "a repository named for pacman's own options section is refused" = { want = false; step.repositories.arch.options = { url = "https://repo.example.invalid/$arch"; inherit key; }; };
    "a repository named for dnf's own main section is refused" = { want = false; step.repositories.fedora.main = { url = "https://repo.example.invalid/"; inherit key; }; };
    "signed metadata declared for an arch repository, whose database must be signed anyway, is refused" = { want = false; step.repositories.arch.declared = { url = "https://repo.example.invalid/$arch"; inherit key; metadataSigned = true; }; };
  };
  urls = {
    "an https URL with a pacman variable is accepted" = { want = true; repository = { url = "https://repo.example.invalid/$repo/$arch"; inherit key; }; };
    "an http repository URL is refused" = { want = false; repository = { url = "http://repo.example.invalid/$arch"; inherit key; }; };
    "a file repository URL is refused" = { want = false; repository = { url = "file:///srv/repo"; inherit key; }; };
    "a repository URL with a second line is refused" = { want = false; repository = { url = "https://repo.example.invalid/$arch\nSigLevel = Never"; inherit key; }; };
    "a repository URL with a space is refused" = { want = false; repository = { url = "https://repo.example.invalid/ x"; inherit key; }; };
    "an http key URL is refused" = { want = false; repository = { url = "https://repo.example.invalid/$arch"; key = key // { url = "http://keys.example.invalid/pinned.asc"; }; }; };
    "a key URL with a second line is refused" = { want = false; repository = { url = "https://repo.example.invalid/$arch"; key = key // { url = "https://keys.example.invalid/pinned.asc\n-o /etc/passwd"; }; }; };
  };

  brokenPackage = program {
    blocked = net // { packages.arch = [ "tailscale" "broken-package" ]; units = [ "tailscaled.service" "shared.service" ]; };
    inherit hypr;
  };
in
pkgs.runCommand "check-root-apply" { } ''
  export FAKE=$TMPDIR/fake DOTFILES_ROOT_PREFIX=$TMPDIR/root PINNED=${pinned} COPR=${copr}
  root=$DOTFILES_ROOT_PREFIX
  mkdir -p $FAKE/bin $FAKE/web
  cp ${./fixtures/root-apply/pinned.asc} $FAKE/pinned.asc
  export GNUPGHOME=$TMPDIR/gnupg
  mkdir -m 700 $GNUPGHOME
  ${pkgs.gnupg}/bin/gpg --batch --quiet --pinentry-mode loopback --passphrase "" --quick-generate-key "root-apply other fixture" ed25519 sign never
  ${pkgs.gnupg}/bin/gpg --batch --armor --export > $FAKE/other.asc
  ${pkgs.gnupg}/bin/gpgconf --kill gpg-agent
  unset GNUPGHOME
  cat > $FAKE/bin/fingerprints <<'EOF'
  #!/bin/sh
  home=$(mktemp -d)
  ${pkgs.gnupg}/bin/gpg --homedir "$home" --batch --show-keys --with-colons "$1" 2>/dev/null \
    | awk -F: '$1 == "pub" { p = 1; next } p && $1 == "fpr" { print $10; p = 0 }'
  rm -rf "$home"
  EOF
  cat > $FAKE/bin/pacman <<'EOF'
  #!/bin/sh
  echo "pacman $*" >> "$FAKE/every-call"
  if [ "$1" = -T ]; then
    echo "$*" >> "$FAKE/queries"
    [ ! -e "$FAKE/db-unreadable" ] || { echo "error: failed to initialize alpm library" >&2; exit 1; }
    shift
    status=0
    for p; do [ -e "$FAKE/pkgs/pacman-$p" ] || [ -e "$FAKE/provides/pacman-$p" ] || { echo "$p"; status=127; }; done
    exit $status
  fi
  echo "$*" >> "$FAKE/calls"
  echo "''${LC_ALL:-}" > "$FAKE/locale"
  case $1 in
    -S)
      if [ -e "$FAKE/locked" ]; then
        echo "error: failed to init transaction (unable to lock database)" >&2
        echo "error: could not lock database: File exists" >&2
        exit 1
      fi
      for p; do
        if [ -e "$FAKE/provides/pacman-$p" ] && [ ! -e "$FAKE/pkgs/pacman-$p" ]; then
          echo ":: $p-1.0-1 and $(cat "$FAKE/provides/pacman-$p") are in conflict. Remove $(cat "$FAKE/provides/pacman-$p")? [y/N] error: unresolvable package conflicts detected" >&2
          echo "error: failed to prepare transaction (conflicting dependencies)" >&2
          exit 1
        fi
      done ;;
    -Sy)
      if [ -e "$FAKE/unreachable" ]; then
        echo "error: failed retrieving file 'hyprrepo.db' from repo.example.invalid : Could not resolve host: repo.example.invalid" >&2
        echo "error: failed to synchronize all databases (failed to retrieve some files)" >&2
        exit 1
      fi
      conf=$DOTFILES_ROOT_PREFIX/etc/pacman.conf
      [ "$2" != --config ] || conf=$3
      cp "$conf" "$FAKE/sync-config"
      echo "$conf" > "$FAKE/sync-config-path"
      mkdir -p "$DOTFILES_ROOT_PREFIX/var/lib/pacman/sync"
      for repo in $(sed -n 's/^\[\(.*\)\]$/\1/p' "$conf" | grep -vx options); do
        echo "synchronized" > "$DOTFILES_ROOT_PREFIX/var/lib/pacman/sync/$repo.db"
        echo "pacman: synchronized $repo"
      done
      exit 0 ;;
    *) exit 2 ;;
  esac
  for p in "$@"; do
    case $p in
      -*) ;;
      *)
        if [ -s "$FAKE/pkgs/pacman-$p" ]; then echo "warning: downgrading package $p ($(cat "$FAKE/pkgs/pacman-$p") => 1.0-1)" >&2
        elif [ -e "$FAKE/pkgs/pacman-$p" ]; then echo "warning: $p-1.0-1 is up to date -- skipping" >&2
        fi ;;
    esac
  done
  for p in "$@"; do
    case $p in
      broken-package) echo "error: target not found: $p" >&2; exit 1 ;;
      multilib-only)
        [ -e "$DOTFILES_ROOT_PREFIX/var/lib/pacman/sync/multilib.db" ] || { echo "error: target not found: $p" >&2; exit 1; } ;;
      hypr-only | hypr-gaming)
        [ -e "$DOTFILES_ROOT_PREFIX/var/lib/pacman/sync/hyprrepo.db" ] || { echo "error: target not found: $p" >&2; exit 1; }
        if [ ! -e "$FAKE/keyring/$PINNED.signed" ] || [ -e "$FAKE/resigned" ]; then
          echo "error: $p: signature from \"Fixture Packager\" is unknown trust" >&2
          echo "error: failed to commit transaction (invalid or corrupted package (PGP signature))" >&2
          exit 1
        fi ;;
    esac
  done
  for p in "$@"; do
    if [ "$1" = -S ] && [ "$p" = "$(cat "$FAKE/gone" 2>/dev/null)" ] && [ ! -e "$FAKE/pkgs/pacman-$p" ]; then
      why="The requested URL returned error: 404"
      [ ! -e "$FAKE/offline" ] || why="Could not resolve host: mirror.example.invalid"
      echo "error: failed retrieving file '$p-1.0-1-x86_64.pkg.tar.zst' from mirror.example.invalid : $why" >&2
      echo "warning: failed to retrieve some files" >&2
      echo "error: failed to commit transaction (failed to retrieve some files)" >&2
      echo "Errors occurred, no packages were upgraded." >&2
      exit 1
    fi
  done
  if [ "$1" = -S ] && [ -e "$FAKE/full" ]; then
    echo "error: Partition / too full: 2048 blocks needed, 1024 blocks free" >&2
    echo "error: failed to commit transaction (not enough free disk space)" >&2
    echo "Errors occurred, no packages were upgraded." >&2
    exit 1
  fi
  for p in "$@"; do
    case $p in -*) ;; *) [ -e "$FAKE/pkgs/pacman-$p" ] && [ ! -s "$FAKE/pkgs/pacman-$p" ] || { : > "$FAKE/pkgs/pacman-$p"; echo "pacman: installed $p"; } ;; esac
  done
  EOF
  cat > $FAKE/bin/pacman-key <<'EOF'
  #!/bin/sh
  case $1 in
    --init) mkdir -p "$FAKE/keyring" ;;
    --list-keys) [ -e "$FAKE/keyring/$2" ] ;;
    --add)
      [ -d "$FAKE/keyring" ] || { echo "==> ERROR: keyring not initialized" >&2; exit 1; }
      for f in $(fingerprints "$2"); do [ -e "$FAKE/keyring/$f" ] || { touch "$FAKE/keyring/$f"; echo "pacman-key: added $f"; }; done ;;
    --lsign-key)
      [ -e "$FAKE/keyring/$2" ] || { echo "==> ERROR: $2 is not in the keyring" >&2; exit 1; }
      touch "$FAKE/keyring/$2.signed"
      echo "pacman-key: locally signed $2" ;;
    *) exit 2 ;;
  esac
  EOF
  cat > $FAKE/bin/dnf <<'EOF'
  #!/bin/sh
  echo "dnf $*" >> "$FAKE/calls"
  echo "dnf $*" >> "$FAKE/every-call"
  [ "$1 $2" = "install -y" ] || exit 2
  shift 2
  echo "''${LC_ALL:-}" > "$FAKE/locale"
  if [ -e "$FAKE/offline" ] && [ ! -e "$FAKE/gone" ]; then
    echo "Failed to download metadata (metalink: \"https://mirrors.example.invalid/metalink?repo=fedora-43&arch=x86_64\") for repository \"fedora\": Librepo error: Curl error (6): Could not resolve hostname for https://mirrors.example.invalid/metalink?repo=fedora-43&arch=x86_64 [Could not resolve host: mirrors.example.invalid]" >&2
    exit 1
  fi
  if [ -e "$FAKE/metadata-gone" ]; then
    echo ">>> Status code: 404 for https://copr.example.invalid/results/fixture/gone/fedora-43-x86_64/repodata/repomd.xml (IP: 192.0.2.1)" >&2
    echo ">>> Error: Failed to download metadata (baseurl: \"https://copr.example.invalid/results/fixture/gone/fedora-43-x86_64/\") for repository \"copr:copr.example.invalid:fixture:gone\": Yum repo downloading error: Downloading error(s): repodata/repomd.xml - Cannot download, all mirrors were already tried without success" >&2
  fi
  for p in "$@"; do [ ! -e "$FAKE/pkgs/dnf-$p" ] || echo "Package \"$p-1.0-1.fc43.x86_64\" is already installed."; done
  for p in "$@"; do
    if [ -e "$FAKE/provides/dnf-$p" ] && [ ! -e "$FAKE/pkgs/dnf-$p" ]; then
      echo "Failed to resolve the transaction:" >&2
      echo "Problem: problem with installed package $(cat "$FAKE/provides/dnf-$p")-1.0-1.fc43.x86_64" >&2
      echo "  - package $(cat "$FAKE/provides/dnf-$p")-1.0-1.fc43.x86_64 from @System conflicts with $p provided by $p-1.0-1.fc43.x86_64 from fedora" >&2
      exit 1
    fi
  done
  for p in "$@"; do
    case $p in
      hypr-only | hypr-gaming)
        repo=$(grep -lxF "[$COPR]" "$DOTFILES_ROOT_PREFIX"/etc/yum.repos.d/*.repo 2>/dev/null | head -1)
        [ -n "$repo" ] || { echo "Failed to resolve the transaction:" >&2; echo "No match for argument: $p" >&2; exit 1; }
        key=$(sed -n 's|^gpgkey=file://||p' "$repo")
        if [ "$(fingerprints "$DOTFILES_ROOT_PREFIX$key")" != "$PINNED" ] || [ -e "$FAKE/resigned" ]; then
          echo " $p  x86_64  1.0-1  copr  10 k"
          echo "Transaction failed: Signature verification failed." >&2
          echo "OpenPGP check for package \"$p-1.0-1.fc43.x86_64\" (/var/cache/libdnf5/copr/packages/$p-1.0-1.fc43.x86_64.rpm) from repo \"$COPR\" has failed: The package is not signed." >&2
          exit 1
        fi ;;
    esac
  done
  for p in "$@"; do
    if [ "$p" = "$(cat "$FAKE/gone" 2>/dev/null)" ] && [ ! -e "$FAKE/pkgs/dnf-$p" ]; then
      why="Status code: 404 for https://mirror.example.invalid/fedora/Packages/$p-1.0-1.fc43.x86_64.rpm (IP: 192.0.2.1)"
      [ ! -e "$FAKE/offline" ] || why="Curl error (6): Could not resolve hostname for https://mirror.example.invalid/fedora/Packages/$p-1.0-1.fc43.x86_64.rpm [Could not resolve host: mirror.example.invalid]"
      echo ">>> $why" >&2
      echo "Failed to download packages" >&2
      echo " Librepo error: Cannot download Packages/$p-1.0-1.fc43.x86_64.rpm: All mirrors were tried" >&2
      exit 1
    fi
  done
  if [ -e "$FAKE/busy" ]; then
    echo "Transaction failed: Failed to obtain rpm transaction lock. Another transaction is in progress." >&2
    exit 1
  fi
  for p in "$@"; do
    case "$p $(cat "$FAKE/rpm-refuses" 2>/dev/null)" in
      "dnf-only check")
        echo "Transaction failed: Rpm transaction check failed." >&2
        echo "  - file /usr/bin/dnf-only from install of $p-1.0-1.fc43.x86_64 conflicts with file from package other-1.0-1.fc43.x86_64" >&2
        exit 1 ;;
      "dnf-only run")
        echo "Transaction failed: Rpm transaction failed." >&2
        exit 1 ;;
    esac
  done
  for p in "$@"; do [ -e "$FAKE/pkgs/dnf-$p" ] || { touch "$FAKE/pkgs/dnf-$p"; echo "dnf: installed $p"; }; done
  EOF
  cat > $FAKE/bin/rpm <<'EOF'
  #!/bin/sh
  echo "rpm $*" >> "$FAKE/queries"
  [ "$1 $2 $3" = "-q --quiet --whatprovides" ] || exit 2
  [ -e "$FAKE/pkgs/dnf-$4" ] || [ -e "$FAKE/provides/dnf-$4" ]
  EOF
  cat > $FAKE/bin/curl <<'EOF'
  #!/bin/sh
  out= url= dest= value=
  echo "$*" >> "$FAKE/curl-calls"
  for a; do
    if [ -n "$value" ]; then value=; continue; fi
    case $a in
      -o) out=1 ;;
      --proto | --proto-redir | --max-time) value=1 ;;
      -*) ;;
      *) if [ -n "$out" ]; then dest=$a; out=; else url=$a; fi ;;
    esac
  done
  echo "$url" >> "$FAKE/fetches"
  [ -e "$FAKE/web/''${url##*/}" ] || { echo "curl: (22) The requested URL returned error: 404" >&2; exit 22; }
  cp "$FAKE/web/''${url##*/}" "$dest"
  EOF
  cat > $FAKE/bin/systemctl <<'EOF'
  #!/bin/sh
  [ "$1" != daemon-reload ] || { echo daemon-reload >> "$FAKE/daemon-reloads"; exit 0; }
  [ "$1 $2" != "disable --now" ] || { rm -f "$FAKE/units/$3"; echo "systemctl: disabled $3"; exit 0; }
  [ "$1 $2" = "enable --now" ] || exit 2
  [ "$3" = missing.service ] && { echo "Unit $3 does not exist" >&2; exit 1; }
  [ -e "$FAKE/units/$3" ] || { touch "$FAKE/units/$3"; echo "systemctl: enabled $3"; }
  EOF
  chmod +x $FAKE/bin/*
  export PATH=$FAKE/bin:$PATH

  pacman_conf='[options]
  HoldPkg = pacman glibc

  [core]
  Include = /etc/pacman.d/mirrorlist

  #[multilib]
  #Include = /etc/pacman.d/mirrorlist'
  fresh() {
    rm -rf "$root" $FAKE/pkgs $FAKE/units $FAKE/keyring $FAKE/fetches $FAKE/calls $FAKE/curl-calls $FAKE/unreachable $FAKE/locked $FAKE/offline $FAKE/resigned $FAKE/full $FAKE/busy $FAKE/gone $FAKE/metadata-gone $FAKE/rpm-refuses $FAKE/daemon-reloads $FAKE/reader-read $FAKE/reader-distro $FAKE/reader-down $FAKE/provides $FAKE/queries $FAKE/db-unreadable
    mkdir -p "$root/etc/yum.repos.d" $FAKE/pkgs $FAKE/units $FAKE/provides
    printf '%s\n' "$@" > "$root/etc/os-release"
    printf '%s\n' "$pacman_conf" > "$root/etc/pacman.conf"
    install -m 0644 $FAKE/pinned.asc $FAKE/web/pinned.asc
  }
  snapshot() { (cd "$root" && { find . $FAKE/pkgs $FAKE/units; find $FAKE/keyring 2>/dev/null || true; } | sort && find . -type f -exec sha256sum {} + | sort); }
  fetches() { cat $FAKE/fetches 2>/dev/null || true; }
  calls() { sed 's/--config [^ ]*/--config CONF/' $FAKE/calls 2>/dev/null || true; }
  syncs() { calls | grep -cx -- '-Sy --config CONF --noconfirm' || true; }
  changes() { grep -v -e '^root step: ' <<< "$1" || true; }
  recorded() { readlink "$root/var/lib/dotfiles/applied" 2>/dev/null || true; }
  failures=0
  fail() { echo "FAIL $1"; echo "$2"; failures=$((failures + 1)); }
  has() { grep -qF -- "$3" <<< "$2" || fail "$1: no '$3' in" "$2"; }

  [ "$(${pkgs.gnupg}/bin/gpg --homedir "$(mktemp -d)" --batch --show-keys --with-colons $FAKE/pinned.asc 2>/dev/null | grep -c '^fpr')" = 2 ] \
    || fail "the pinned fixture key has a subkey" ""
  [ "$(fingerprints $FAKE/other.asc | wc -l)" = 1 ] && [ "$(fingerprints $FAKE/other.asc)" != "$PINNED" ] || fail "the other fixture key is one key, not the pinned one" "$(fingerprints $FAKE/other.asc)"
  key=/etc/pki/rpm-gpg/RPM-GPG-KEY-copr-copr.example.invalid-fixture-hyprrepo

  real=${(built both).rootApply}/bin/dotfiles-root-apply
  ! grep -q DOTFILES_ROOT_PREFIX $real || fail "the real program has no scratch prefix" "$(grep -n DOTFILES_ROOT_PREFIX $real)"
  grep -q 'run as root' $real || fail "the real program checks for root" ""
  same=$(diff <(sed 's/.*run as root.*//' $real) <(sed 's/\$DOTFILES_ROOT_PREFIX//g' ${converging})) \
    || fail "the scratch program is the real one plus a prefix, minus the uid check" "$same"

  ${lib.concatStrings (lib.mapAttrsToList
    (what: c: lib.optionalString (evaluates c.step != c.want) "fail ${lib.escapeShellArg what} ''\n")
    declarations)}
  fresh ID=arch
  first=$(${converging} 2>&1) || fail "first apply exits 0" "$first"
  for line in "pacman: installed tailscale" "pacman: installed jq" "installed /etc/net.conf" \
    "installed /etc/arch-only.conf" "systemctl: enabled tailscaled.service" "root step: net"; do
    has "first apply converges" "$first" "$line"
  done
  [ "$(stat -c %a "$root/etc/arch-only.conf")" = 600 ] || fail "file mode is applied" ""
  [ "$(cat "$root/etc/net.d/env")" = "arch arch " ] || fail "a script sees DISTRO, ID and an empty VERSION_ID" "$(cat "$root/etc/net.d/env" 2>&1)"
  [ "$(recorded)" = ${converging} ] || fail "a clean run records itself" "$(recorded)"
  has "a repository's package installs, so the repository came first" "$first" "pacman: installed hypr-only"
  [ -e "$FAKE/keyring/$PINNED.signed" ] || fail "the pinned key is trusted" "$first"
  printf -v want '%s\n\n%s\n%s\n%s' "$pacman_conf" "[hyprrepo]" "SigLevel = Required DatabaseRequired" 'Server = https://repo.example.invalid/$arch'
  [ "$(cat "$root/etc/pacman.conf")" = "$want" ] || fail "the section is appended and the rest of pacman.conf is kept" "$(cat "$root/etc/pacman.conf")"
  [ "$(fetches)" = https://keys.example.invalid/pinned.asc ] || fail "the key is fetched from its declared URL" "$(fetches)"
  for flag in "--proto =https" "--proto-redir =https" "--tlsv1.2" "--max-time "; do
    has "a key is fetched over https only, with modern TLS and a time limit" "$(cat $FAKE/curl-calls)" "$flag"
  done
  [ "$(syncs)" = 1 ] || fail "a repository with no database costs one sync" "$(calls)"
  grep -q 'syncing the package databases.*hyprrepo' <<< "$first" || fail "a sync is announced with the repository that needs it" "$first"
  before=$(snapshot)
  : > $FAKE/fetches
  : > $FAKE/calls
  second=$(${converging} 2>&1) || fail "second apply exits 0" "$second"
  [ -z "$(changes "$second")" ] || fail "second apply reports no changes" "$second"
  [ "$before" = "$(snapshot)" ] || fail "second apply changes nothing" "$(diff <(echo "$before") <(snapshot))"
  [ -z "$(fetches)" ] || fail "second apply fetches no key" "$(fetches)"
  [ "$(syncs)" = 0 ] || fail "second apply runs no sync" "$(calls)"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d" "$root/etc/hooks.d"
  echo distro > "$root/etc/pam.d/lock"
  printf '#!/bin/sh\necho theirs\n' > "$root/etc/hooks.d/60-hook"
  chmod 0755 "$root/etc/hooks.d/60-hook"
  backed=$(${withLock} 2>&1) || fail "apply over files that were already there exits 0" "$backed"
  [ "$(cat "$root/etc/pam.d/lock")" = ours ] || fail "a file that was already there gets the declared content" "$backed"
  [ "$(cat "$root/etc/pam.d/lock.pre-nix" 2>&1)" = distro ] || fail "a file that was already there keeps one copy beside it" "$(ls -la "$root/etc/pam.d")"
  [ "$(sed -n 2p "$root/etc/hooks.d/60-hook.pre-nix" 2>&1)" = "echo theirs" ] || fail "a program that was already there keeps one copy beside it" "$(ls -la "$root/etc/hooks.d")"
  [ ! -x "$root/etc/hooks.d/60-hook.pre-nix" ] || fail "the copy of a program cannot run, so a directory that runs every program in it does not run it" "$(ls -la "$root/etc/hooks.d")"
  [ ! -e "$root/etc/arch-only.conf.pre-nix" ] || fail "a file the program created gets no copy" "$(ls -la "$root/etc")"
  before=$(snapshot)
  second=$(${withLock} 2>&1) || fail "second apply over files that were already there exits 0" "$second"
  [ -z "$(changes "$second")" ] && [ "$before" = "$(snapshot)" ] || fail "second apply over files that were already there changes nothing" "$second"
  changed=$(${withLockChanged} 2>&1) || fail "apply of changed content exits 0" "$changed"
  [ "$(cat "$root/etc/pam.d/lock")" = "ours, changed" ] || fail "changed content is written" "$changed"
  [ "$(cat "$root/etc/pam.d/lock.pre-nix")" = distro ] || fail "an existing copy is never replaced" "$(cat "$root/etc/pam.d/lock.pre-nix")"
  [ "$(cat "$root/etc/arch-only.conf")" = "arch, changed" ] && [ ! -e "$root/etc/arch-only.conf.pre-nix" ] \
    || fail "a file the program created is rewritten with no copy" "$(ls -la "$root/etc")"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo ours > "$root/etc/pam.d/lock"
  ${withLock} > /dev/null 2>&1 || fail "apply over a file that already holds the declared content exits 0" ""
  [ ! -e "$root/etc/pam.d/lock.pre-nix" ] || fail "a file that already holds the declared content gets no copy" "$(ls -la "$root/etc/pam.d")"
  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo ours > "$root/etc/pam.d/lock.real"
  ln -s lock.real "$root/etc/pam.d/lock"
  ${withLock} > /dev/null 2>&1 || fail "apply over a link to a file with the declared content exits 0" ""
  [ -L "$root/etc/pam.d/lock" ] && [ ! -e "$root/etc/pam.d/lock.pre-nix" ] || fail "a link to a file that already holds the declared content is left alone" "$(ls -la "$root/etc/pam.d")"
  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo ours > "$root/etc/pam.d/lock"
  chmod 0600 "$root/etc/pam.d/lock"
  ${withLock} > /dev/null 2>&1 || fail "apply over a file with another mode exits 0" ""
  [ "$(stat -c %a "$root/etc/pam.d/lock")" = 644 ] && [ "$(stat -c %a "$root/etc/pam.d/lock.pre-nix" 2>&1)" = 600 ] \
    || fail "a file whose mode alone changes keeps a copy with the mode it had" "$(ls -la "$root/etc/pam.d")"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d" "$root/etc/hooks.d"
  echo distro > "$root/etc/pam.d/lock"
  printf '#!/bin/sh\necho theirs\n' > "$root/etc/hooks.d/60-hook"
  chmod 0755 "$root/etc/hooks.d/60-hook"
  ${withLock} > /dev/null 2>&1 || fail "the apply before a step leaves exits 0" ""
  [ "$(cat "$root/var/lib/dotfiles/files")" = /etc/arch-only.conf ] || fail "only a file the program created is listed for removal" "$(cat "$root/var/lib/dotfiles/files")"
  if result=$(${withLockBlocked} 2>&1); then fail "a failed package beside a file that was there before makes the run exit 1" "$result"; fi
  [ "$(cat "$root/etc/pam.d/lock")" = ours ] && [ "$(cat "$root/etc/pam.d/lock.pre-nix" 2>&1)" = distro ] \
    || fail "a skipped step's file that was there before stays as the program left it" "$result"
  echo ID=debian > "$root/etc/os-release"
  if result=$(${onlyArchOnly} 2>&1); then fail "an unknown distro beside a file that was there before exits 1" "$result"; fi
  [ "$(cat "$root/etc/pam.d/lock")" = ours ] && [ "$(cat "$root/etc/pam.d/lock.pre-nix" 2>&1)" = distro ] \
    || fail "an unknown distro puts no file back" "$result"
  echo ID=arch > "$root/etc/os-release"
  left=$(${onlyArchOnly} 2>&1) || fail "apply without the steps exits 0" "$left"
  [ "$(cat "$root/etc/pam.d/lock" 2>&1)" = distro ] || fail "a file that was there before its step is put back as it was when the step goes, not removed" "$left"
  [ "$(sed -n 2p "$root/etc/hooks.d/60-hook" 2>&1)" = "echo theirs" ] && [ -x "$root/etc/hooks.d/60-hook" ] \
    || fail "a program that was there before its step is put back with the mode it had" "$(ls -la "$root/etc/hooks.d")"
  [ -z "$(find "$root/etc" -name '*.pre-nix')" ] || fail "a copy that was put back is gone" "$(find "$root/etc" -name '*.pre-nix')"
  [ "$(changes "$left")" = "$(printf '%s\n' "restored /etc/hooks.d/60-hook" "restored /etc/pam.d/lock")" ] || fail "the files put back are the only change" "$left"
  before=$(snapshot)
  again=$(${onlyArchOnly} 2>&1) || fail "the apply after files were put back exits 0" "$again"
  [ -z "$(changes "$again")" ] && [ "$before" = "$(snapshot)" ] || fail "the apply after files were put back changes nothing" "$again"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo ours > "$root/etc/pam.d/lock"
  ${withLock} > /dev/null 2>&1 || fail "apply over a file that already holds the declared content exits 0" ""
  left=$(${onlyArchOnly} 2>&1) || fail "apply without a step whose file was already there exits 0" "$left"
  [ "$(cat "$root/etc/pam.d/lock" 2>&1)" = ours ] || fail "a file that already held the declared content stays when its step goes" "$left"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo distro > "$root/etc/pam.d/lock"
  ${lockTwice} > /dev/null 2>&1 || fail "apply of a file two steps declare exits 0" "$(${lockTwice} 2>&1)"
  left=$(${onlyArchOnly} 2>&1) || fail "apply without the two steps that declared a file exits 0" "$left"
  [ "$(cat "$root/etc/pam.d/lock" 2>&1)" = distro ] || fail "a file two steps declared is put back as it was" "$left"
  [ "$(changes "$left")" = "$(printf '%s\n' "removed /etc/hooks.d/60-hook" "restored /etc/pam.d/lock")" ] \
    || fail "a file two steps declared is put back once, and nothing is said about a copy that is gone" "$left"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d" "$root/etc/hooks.d"
  echo distro > "$root/etc/pam.d/lock.real"
  ln -s lock.real "$root/etc/pam.d/lock"
  printf '#!/bin/sh\necho theirs\n' > "$root/etc/hook.real"
  chmod 0755 "$root/etc/hook.real"
  ln -s ../hook.real "$root/etc/hooks.d/60-hook"
  linked=$(${withLock} 2>&1) || fail "apply over links that were already there exits 0" "$linked"
  [ ! -L "$root/etc/pam.d/lock" ] && [ "$(cat "$root/etc/pam.d/lock")" = ours ] && [ "$(cat "$root/etc/pam.d/lock.real")" = distro ] \
    || fail "a link that was already there gives way to the declared file, and what it pointed at is left alone" "$(ls -la "$root/etc/pam.d")"
  [ "$(ls "$root/etc/hooks.d")" = 60-hook ] || fail "the copy of a link is not kept where every program is run" "$(ls -la "$root/etc/hooks.d")"
  before=$(snapshot)
  second=$(${withLock} 2>&1) || fail "second apply over links that were already there exits 0" "$second"
  [ -z "$(changes "$second")" ] && [ "$before" = "$(snapshot)" ] || fail "second apply over links that were already there changes nothing" "$second"
  left=$(${onlyArchOnly} 2>&1) || fail "apply without the steps whose files were links exits 0" "$left"
  [ "$(readlink "$root/etc/pam.d/lock")" = lock.real ] && [ "$(readlink "$root/etc/hooks.d/60-hook")" = ../hook.real ] \
    || fail "a link that was there before its step is put back as the link it was" "$(ls -la "$root/etc/pam.d" "$root/etc/hooks.d")"
  [ "$(cat "$root/etc/pam.d/lock.real")" = distro ] && [ -x "$root/etc/hook.real" ] || fail "what a link pointed at is as it was" "$(ls -la "$root/etc")"
  [ "$(changes "$left")" = "$(printf '%s\n' "restored /etc/hooks.d/60-hook" "restored /etc/pam.d/lock")" ] || fail "the links put back are the only change" "$left"
  before=$(snapshot)
  again=$(${onlyArchOnly} 2>&1) || fail "the apply after links were put back exits 0" "$again"
  [ -z "$(changes "$again")" ] && [ "$before" = "$(snapshot)" ] || fail "the apply after links were put back changes nothing" "$again"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  ln -s missing "$root/etc/pam.d/lock"
  ${withLock} > /dev/null 2>&1 || fail "apply over a dangling link exits 0" "$(${withLock} 2>&1)"
  [ ! -L "$root/etc/pam.d/lock" ] && [ "$(cat "$root/etc/pam.d/lock")" = ours ] || fail "a dangling link gives way to the declared file" "$(ls -la "$root/etc/pam.d")"
  left=$(${onlyArchOnly} 2>&1) || fail "apply without a step whose file was a dangling link exits 0" "$left"
  [ "$(readlink "$root/etc/pam.d/lock" 2>&1)" = missing ] || fail "a dangling link that was there before its step is put back, not removed as a file the program created" "$left"

  reads() { wc -l < $FAKE/reader-read 2>/dev/null || echo 0; }
  daemon_reloads() { wc -l < $FAKE/daemon-reloads 2>/dev/null || echo 0; }
  fresh ID=arch
  mkdir -p "$root/etc/units.d"
  echo "the owner's" > "$root/etc/units.d/a.conf"
  ${withReloads} > /dev/null 2>&1 || fail "apply of files with a reload exits 0" "$(${withReloads} 2>&1)"
  [ "$(cat $FAKE/reader-read 2>&1)" = one ] || fail "a new file's reload runs once the file is written" "$(cat $FAKE/reader-read 2>&1)"
  [ "$(cat $FAKE/reader-distro 2>&1)" = arch ] || fail "a reload sees DISTRO, as a script does" "$(cat $FAKE/reader-distro 2>&1)"
  [ "$(daemon_reloads)" = 1 ] || fail "two files with the same reload run it once" "$(daemon_reloads)"
  ${withReloads} > /dev/null 2>&1 || fail "second apply of files with a reload exits 0" ""
  [ "$(reads)" = 1 ] && [ "$(daemon_reloads)" = 1 ] || fail "a file that did not change is not reloaded again" "$(reads) $(daemon_reloads)"
  ${withReloadsChanged} > /dev/null 2>&1 || fail "apply of a changed file with a reload exits 0" ""
  [ "$(tail -n 1 $FAKE/reader-read)" = two ] && [ "$(reads)" = 2 ] && [ "$(daemon_reloads)" = 1 ] \
    || fail "a changed file is reloaded, and files that did not change are not" "$(cat $FAKE/reader-read) $(daemon_reloads)"
  touch $FAKE/reader-down
  if result=$(${withReloads} 2>&1); then fail "a reload that fails makes the run exit 1" "$result"; fi
  has "a reload that fails names its file" "$result" "dotfiles-root-apply: the reload for /etc/reader.d/powersave.conf failed, continuing"
  [ -z "$(recorded)" ] || fail "a run whose reload failed is not recorded" "$(recorded)"
  if result=$(${withReloads} 2>&1); then fail "a reload that fails again makes the run exit 1" "$result"; fi
  [ "$(reads)" = 4 ] || fail "a reload that failed is tried again by the next run, though the file did not change" "$(reads)"
  rm $FAKE/reader-down
  ${withReloads} > /dev/null 2>&1 || fail "the run whose reload works exits 0" "$(${withReloads} 2>&1)"
  ${withReloads} > /dev/null 2>&1 || fail "the run after a reload worked exits 0" ""
  [ "$(reads)" = 5 ] || fail "a reload that worked is not run again" "$(reads)"
  left=$(${onlyArchOnly} 2>&1) || fail "apply without the steps whose files had a reload exits 0" "$left"
  [ "$(tail -n 1 $FAKE/reader-read)" = nothing ] && [ "$(reads)" = 6 ] || fail "a removed file's reload runs after the file is gone, though no step declares it" "$(cat $FAKE/reader-read)"
  [ "$(cat "$root/etc/units.d/a.conf")" = "the owner's" ] && [ ! -e "$root/etc/units.d/b.conf" ] && [ "$(daemon_reloads)" = 2 ] \
    || fail "a file that is put back and one that is removed have their one reload run once" "$(daemon_reloads)"
  ${onlyArchOnly} > /dev/null 2>&1 || fail "the apply after files with a reload went exits 0" ""
  [ "$(reads)" = 6 ] && [ "$(daemon_reloads)" = 2 ] || fail "a reload for a file that went is not run again" "$(reads) $(daemon_reloads)"
  fresh ID=arch
  mkdir -p "$root/etc/reader.d"
  echo theirs > "$root/etc/reader.d/powersave.conf"
  ${withReloads} > /dev/null 2>&1 || fail "apply over a file with a reload that was already there exits 0" ""
  ${onlyArchOnly} > /dev/null 2>&1 || fail "apply without a step whose file with a reload was already there exits 0" ""
  [ "$(cat $FAKE/reader-read)" = "$(printf '%s\n' one theirs)" ] || fail "a file that is put back is reloaded once it is back" "$(cat $FAKE/reader-read)"

  fresh ID=arch
  ${withReloads} > /dev/null 2>&1 || fail "apply of files with a reload, before it starts failing, exits 0" ""
  touch $FAKE/reader-down
  if result=$(${withReloadsChanged} 2>&1); then fail "a changed file whose reload fails makes the run exit 1" "$result"; fi
  if result=$(${onlyArchOnly} 2>&1); then fail "the run that removes a file whose reload still fails exits 1" "$result"; fi
  [ "$(reads)" = 3 ] || fail "a removed file's failing reload is tried once more, with the removal" "$(reads)"
  result=$(${onlyArchOnly} 2>&1) || fail "a failed reload whose file no step declares any more does not fail every later run" "$result"
  has "a failed reload whose file no step declares any more is dropped" "$result" "dropped the pending reload for /etc/reader.d/powersave.conf"
  [ "$(reads)" = 3 ] || fail "a dropped reload does not run" "$(reads)"
  [ -z "$(ls -A "$root/var/lib/dotfiles/pending" 2>/dev/null)" ] || fail "a dropped reload leaves nothing pending" "$(ls -A "$root/var/lib/dotfiles/pending")"

  fresh ID=arch
  echo "Key = theirs" > "$root/etc/distro.conf"
  chmod 0755 "$root/etc/distro.conf"
  echo first > "$root/etc/want"
  edited=$(${editing} 2>&1) || fail "apply of a script that edits a distro file exits 0" "$edited"
  [ "$(cat "$root/etc/distro.conf")" = "Key = ours" ] || fail "a script edits the distro's file" "$edited"
  [ "$(cat "$root/etc/distro.conf.pre-nix" 2>&1)" = "Key = theirs" ] || fail "a file a script edits keeps one copy from before the edit" "$(ls -la "$root/etc")"
  [ ! -x "$root/etc/distro.conf.pre-nix" ] || fail "the copy of a file a script edits cannot run" "$(ls -la "$root/etc")"
  [ "$(cat "$root/etc/own.conf")" = first ] && [ ! -e "$root/etc/own.conf.pre-nix" ] || fail "a file a script creates gets no copy" "$(ls -la "$root/etc")"
  echo "Key = the owner's" > "$root/etc/distro.conf"
  echo second > "$root/etc/want"
  edited=$(${editing} 2>&1) || fail "apply of a script that edits its files again exits 0" "$edited"
  [ "$(cat "$root/etc/distro.conf")" = "Key = ours" ] && [ "$(cat "$root/etc/distro.conf.pre-nix")" = "Key = theirs" ] \
    || fail "the copy of a file a script edits is never replaced" "$(cat "$root/etc/distro.conf.pre-nix")"
  [ "$(cat "$root/etc/own.conf")" = second ] && [ ! -e "$root/etc/own.conf.pre-nix" ] \
    || fail "a file a script created on an earlier run gets no copy when the script edits it" "$(ls -la "$root/etc")"

  fresh ID=arch
  mkdir -p "$root/etc/pam.d"
  echo distro > "$root/etc/pam.d/lock"
  echo older > "$root/etc/pam.d/lock.pre-nix"
  ${withLock} > /dev/null 2>&1 || fail "apply over a file with a copy beside it exits 0" ""
  [ "$(cat "$root/etc/pam.d/lock")" = ours ] && [ "$(cat "$root/etc/pam.d/lock.pre-nix")" = older ] \
    || fail "a copy that is already beside a file is never replaced" "$(cat "$root/etc/pam.d/lock.pre-nix")"

  fresh ID=arch
  ${converging} > /dev/null 2>&1 || fail "the apply that first changes pacman.conf exits 0" ""
  [ "$(cat "$root/etc/pacman.conf.pre-nix" 2>&1)" = "$pacman_conf" ] || fail "pacman.conf keeps one copy from before its first change" "$(ls -la "$root/etc")"
  ${withLib32} > /dev/null 2>&1 || fail "the apply that changes pacman.conf again exits 0" ""
  grep -qx '\[multilib\]' "$root/etc/pacman.conf" || fail "pacman.conf is changed a second time" "$(cat "$root/etc/pacman.conf")"
  [ "$(cat "$root/etc/pacman.conf.pre-nix")" = "$pacman_conf" ] || fail "the copy of pacman.conf is never replaced" "$(cat "$root/etc/pacman.conf.pre-nix")"

  fresh ID=arch
  mkdir -p $FAKE/keyring "$root/var/lib/pacman/sync"
  touch $FAKE/keyring/$PINNED $FAKE/keyring/$PINNED.signed "$root/var/lib/pacman/sync/hyprrepo.db"
  printf '\n[hyprrepo]\nSigLevel = Required DatabaseRequired\nServer = %s\n' 'https://repo.example.invalid/$arch' >> "$root/etc/pacman.conf"
  conf=$(sha256sum < "$root/etc/pacman.conf")
  installed=$(${converging} 2>&1) || fail "apply over an installer-configured repository exits 0" "$installed"
  [ "$conf" = "$(sha256sum < "$root/etc/pacman.conf")" ] || fail "a repository configured identically is left alone" "$(cat "$root/etc/pacman.conf")"
  [ -z "$(fetches)" ] || fail "a repository configured identically fetches no key" "$(fetches)"
  has "a repository configured identically still serves its package" "$installed" "pacman: installed hypr-only"
  case $installed in *pacman-key:* | *"configured repository"*) fail "a repository configured identically is not set up again" "$installed" ;; esac
  [ "$(syncs)" = 0 ] || fail "a repository whose database exists costs no sync" "$(calls)"
  [ ! -e "$root/etc/pacman.conf.pre-nix" ] || fail "a pacman.conf that is left alone gets no copy" "$(ls "$root/etc")"

  fresh ID=arch
  mkdir -p $FAKE/keyring "$root/var/lib/pacman/sync"
  touch $FAKE/keyring/$PINNED $FAKE/keyring/$PINNED.signed "$root/var/lib/pacman/sync/hyprrepo.db"
  printf '\n[hyprrepo]\nSigLevel = Optional TrustAll\nServer = %s\n' 'https://repo.example.invalid/$arch' >> "$root/etc/pacman.conf"
  tightened=$(${converging} 2>&1) || fail "apply over a repository with signature checking off exits 0" "$tightened"
  grep -qx 'SigLevel = Required DatabaseRequired' "$root/etc/pacman.conf" || fail "a repository with signature checking off gets it turned on" "$(cat "$root/etc/pacman.conf")"
  ! grep -q 'TrustAll' "$root/etc/pacman.conf" || fail "the old signature level is gone" "$(cat "$root/etc/pacman.conf")"
  has "a tightened repository still serves its package" "$tightened" "pacman: installed hypr-only"
  [ "$(syncs)" = 0 ] || fail "tightening a repository's signature level costs no sync" "$(calls)"

  fresh ID=arch
  mkdir -p $FAKE/keyring "$root/var/lib/pacman/sync"
  touch $FAKE/keyring/$PINNED $FAKE/keyring/$PINNED.signed "$root/var/lib/pacman/sync/hyprrepo.db"
  printf '\n[hyprrepo]\nSigLevel = Required DatabaseRequired\nServer = %s\n' 'https://old.example.invalid/$arch' >> "$root/etc/pacman.conf"
  moved=$(${converging} 2>&1) || fail "apply over a repository on another server exits 0" "$moved"
  [ "$(syncs)" = 1 ] || fail "a repository moved to another server costs one sync" "$(calls)"

  fresh ID=arch
  mkdir -p $FAKE/keyring
  touch $FAKE/keyring/$PINNED $FAKE/keyring/$PINNED.signed
  printf '\n[hyprrepo]\nSigLevel = Required DatabaseRequired\nServer = %s\n' 'https://repo.example.invalid/$arch' >> "$root/etc/pacman.conf"
  mkdir -p "$root/var/lib/pacman/sync"
  echo "core as it was" > "$root/var/lib/pacman/sync/core.db"
  unsynced=$(${converging} 2>&1) || fail "apply over a repository that was never synced exits 0" "$unsynced"
  [ "$(syncs)" = 1 ] || fail "a configured repository with no database is synced" "$(calls)"
  has "a repository synced late serves its package" "$unsynced" "pacman: installed hypr-only"
  [ "$(cat "$root/var/lib/pacman/sync/core.db")" = "core as it was" ] \
    || fail "syncing a repository with no database leaves the distro's databases alone" "$(cat "$root/var/lib/pacman/sync/core.db"; cat $FAKE/sync-config)"
  printf -v want '%s\n%s\n\n%s\n%s\n%s' "[options]" "HoldPkg = pacman glibc" "[hyprrepo]" "SigLevel = Required DatabaseRequired" 'Server = https://repo.example.invalid/$arch'
  [ "$(cat $FAKE/sync-config)" = "$want" ] || fail "the sync reads the system's options and only the repositories with no database" "$(cat $FAKE/sync-config)"
  [ ! -e "$(cat $FAKE/sync-config-path)" ] || fail "the sync configuration is removed after the sync" "$(cat $FAKE/sync-config-path)"

  fresh ID=arch
  mkdir -p $FAKE/keyring
  touch $FAKE/keyring/$PINNED $FAKE/keyring/$PINNED.signed $FAKE/pkgs/pacman-tailscale $FAKE/pkgs/pacman-jq $FAKE/pkgs/pacman-hypr-only
  printf '\n[hyprrepo]\nSigLevel = Required DatabaseRequired\nServer = %s\n' 'https://repo.example.invalid/$arch' >> "$root/etc/pacman.conf"
  idle=$(${converging} 2>&1) || fail "apply over a repository never synced, with nothing to install, exits 0" "$idle"
  [ -z "$(calls)" ] || fail "a repository never synced, with nothing to install, costs no pacman call" "$(calls)"
  case $idle in *"syncing the package databases"*) fail "a repository never synced, with nothing to install, announces no sync" "$idle" ;; esac
  [ ! -e "$root/var/lib/pacman/sync/hyprrepo.db" ] || fail "a repository never synced, with nothing to install, stays unsynced" ""
  [ "$(recorded)" = ${converging} ] || fail "a run with nothing to install over a repository never synced is recorded" "$(recorded)"
  rm $FAKE/pkgs/pacman-hypr-only
  one=$(${converging} 2>&1) || fail "apply over a repository never synced, with one package to install, exits 0" "$one"
  [ "$(calls)" = "$(printf '%s\n' "-Sy --config CONF --noconfirm" "-S --needed --noconfirm hypr-only")" ] \
    || fail "a repository never synced, with one package to install, syncs once and installs only that package" "$(calls)"

  fresh ID=arch
  install -m 0644 $FAKE/other.asc $FAKE/web/pinned.asc
  if result=$(${converging} 2>&1); then fail "a key that is not the pinned one makes the run exit 1" "$result"; fi
  has "a key that is not the pinned one is refused" "$result" "is not the pinned key"
  has "a refused repository is reported" "$result" "repository hyprrepo failed, continuing"
  [ -z "$(ls $FAKE/keyring 2>/dev/null)" ] || fail "a refused key is not added" "$(ls $FAKE/keyring)"
  [ "$(cat "$root/etc/pacman.conf")" = "$pacman_conf" ] || fail "a refused repository writes no section" "$(cat "$root/etc/pacman.conf")"
  [ ! -e "$root/etc/hypr.conf" ] || fail "a step whose package needs a refused repository is skipped" "$result"
  [ -e "$root/etc/net.conf" ] || fail "a refused repository does not stop other steps" "$result"
  [ -z "$(recorded)" ] || fail "a refused repository is not recorded" "$(recorded)"
  [ "$(syncs)" = 0 ] || fail "a refused repository costs no sync" "$(calls)"
  cat $FAKE/pinned.asc $FAKE/other.asc > $FAKE/web/pinned.asc
  if result=$(${converging} 2>&1); then fail "a key file with an extra key makes the run exit 1" "$result"; fi
  has "a key file with an extra key is refused" "$result" "is not the pinned key"
  [ -z "$(ls $FAKE/keyring 2>/dev/null)" ] || fail "a key file with an extra key adds nothing" "$(ls $FAKE/keyring)"

  fresh ID=arch
  if result=$(${subkeyPinned} 2>&1); then fail "a pin on a subkey makes the run exit 1" "$result"; fi
  has "a key is not the pinned one because a subkey of it is" "$result" "is not the pinned key"
  [ -z "$(ls $FAKE/keyring 2>/dev/null)" ] || fail "a key matched only by a subkey is not added" "$(ls $FAKE/keyring)"

  fresh ID=arch
  borrowed=$(${borrowing} 2>&1) || fail "apply of a step that needs another step's repository exits 0" "$borrowed"
  has "a package installs from a repository another step declares" "$borrowed" "pacman: installed hypr-gaming"
  [ -e "$root/etc/gaming.conf" ] || fail "a step that needs another step's repository is applied" "$borrowed"
  fresh ID=arch
  if borrowed=$(${borrowingRetried} 2>&1); then fail "a failed package beside a borrowed repository makes the run exit 1" "$borrowed"; fi
  has "a package installs from another step's repository when each step is installed on its own" "$borrowed" "pacman: installed hypr-gaming"
  [ -e "$root/etc/gaming.conf" ] || fail "a step that needs another step's repository is applied when each step is installed on its own" "$borrowed"
  fresh ID=fedora VERSION_ID=43
  borrowed=$(${borrowing} 2>&1) || fail "fedora apply of a step that needs another step's repository exits 0" "$borrowed"
  has "a package installs from a repository another step declares, on fedora" "$borrowed" "dnf: installed hypr-gaming"

  fresh ID=arch
  multilib=$(${withLib32} 2>&1) || fail "apply with a distro repository exits 0" "$multilib"
  printf -v want '%s\n\n%s\n%s\n\n%s\n%s\n%s' "$pacman_conf" "[multilib]" "Include = /etc/pacman.d/mirrorlist" \
    "[hyprrepo]" "SigLevel = Required DatabaseRequired" 'Server = https://repo.example.invalid/$arch'
  [ "$(cat "$root/etc/pacman.conf")" = "$want" ] || fail "a distro repository is its name and the mirror list, written before the others" "$(cat "$root/etc/pacman.conf")"
  has "a distro repository's package installs" "$multilib" "pacman: installed multilib-only"
  [ "$(fetches)" = https://keys.example.invalid/pinned.asc ] || fail "a distro repository fetches no key" "$(fetches)"
  [ "$(syncs)" = 1 ] || fail "a distro repository and another one cost one sync between them" "$(calls)"
  grep -q 'syncing the package databases.*multilib' <<< "$multilib" || fail "a sync names the distro repository that needs it" "$multilib"
  before=$(snapshot)
  : > $FAKE/calls
  second=$(${withLib32} 2>&1) || fail "second apply with a distro repository exits 0" "$second"
  [ -z "$(changes "$second")" ] && [ "$before" = "$(snapshot)" ] && [ "$(syncs)" = 0 ] \
    || fail "second apply with a distro repository changes nothing and runs no sync" "$second"

  fresh ID=arch
  sed -i 's/^#\(\[multilib\]\|Include\)/\1/' "$root/etc/pacman.conf"
  mkdir -p "$root/var/lib/pacman/sync"
  touch "$root/var/lib/pacman/sync/multilib.db"
  conf=$(sha256sum < "$root/etc/pacman.conf")
  enabled=$(${onlyLib32} 2>&1) || fail "apply over a distro repository already enabled exits 0" "$enabled"
  [ "$conf" = "$(sha256sum < "$root/etc/pacman.conf")" ] || fail "a distro repository already enabled is left alone" "$(cat "$root/etc/pacman.conf")"
  [ "$(syncs)" = 0 ] || fail "a distro repository already enabled and synced costs no sync" "$(calls)"
  has "a distro repository already enabled serves its package" "$enabled" "pacman: installed multilib-only"

  fresh ID=fedora VERSION_ID=43
  ${onlyLib32} > /dev/null 2>&1 || fail "a distro repository declared for arch does nothing on fedora" "$(${onlyLib32} 2>&1)"
  [ -z "$(ls "$root/etc/yum.repos.d")" ] && [ -z "$(calls)" ] && [ "$(cat "$root/etc/pacman.conf")" = "$pacman_conf" ] \
    || fail "a distro repository declared for arch touches no repository on fedora" "$(ls "$root/etc/yum.repos.d"; calls; cat "$root/etc/pacman.conf")"

  fresh ID=arch
  touch $FAKE/unreachable
  if result=$(${converging} 2>&1); then fail "a failed sync makes the run exit 1" "$result"; fi
  [ "$(calls)" = "-Sy --config CONF --noconfirm" ] || fail "a failed sync is not repeated, and no package is installed without it" "$(calls)"
  has "a failed sync is reported" "$result" "dotfiles-root-apply: syncing the package databases failed"
  case $result in *"look stale"*) fail "a mirror that cannot be reached is not called a stale database" "$result" ;; esac
  [ ! -e "$root/etc/net.conf" ] && [ ! -e "$root/etc/hypr.conf" ] || fail "a failed sync skips every step with packages" "$result"
  [ -e "$root/etc/arch-only.conf" ] || fail "a failed sync does not stop a step with no packages" "$result"
  [ -z "$(recorded)" ] || fail "a failed sync is not recorded" "$(recorded)"
  rm $FAKE/unreachable
  rerun=$(${converging} 2>&1) || fail "the next run, with the repository reachable, exits 0" "$rerun"
  [ -e "$root/etc/net.conf" ] && [ -e "$root/etc/hypr.conf" ] || fail "the next run applies the steps a failed sync skipped" "$rerun"

  fresh ID=arch
  if result=$(${brokenPackage} 2>&1); then fail "a failed package on a fresh machine makes the run exit 1" "$result"; fi
  [ "$(syncs)" = 1 ] || fail "a failed package on a fresh machine costs one sync, not one for each step" "$(calls)"
  [ -e "$root/etc/hypr.conf" ] || fail "a failed package on a fresh machine does not stop another step" "$result"

  fresh ID=arch

  without_bash=$(tr ':' '\n' <<< "$PATH" | grep -vxF "$(dirname "$(command -v bash)")" | paste -sd:)
  PATH=$without_bash ${converging} > /dev/null 2>&1 || fail "a script runs with no bash on PATH" "$(PATH=$without_bash ${converging} 2>&1)"

  third=$(${withoutArchOnly} 2>&1) || fail "apply without the arch-only step exits 0" "$third"
  [ "$(changes "$third")" = "removed /etc/arch-only.conf" ] || fail "a removed step's file is the only change" "$third"
  [ ! -e "$root/etc/arch-only.conf" ] || fail "a removed step's file is deleted" "$third"
  [ -e "$root/etc/net.conf" ] || fail "a kept step's file stays" "$third"
  [ "$(cat "$root/var/lib/dotfiles/files")" = "$(printf "%s\n" /etc/hypr.conf /etc/net.conf)" ] || fail "the file list holds what is declared now" "$(cat "$root/var/lib/dotfiles/files")"

  fresh ID=arch
  ${converging} > /dev/null 2>&1 || fail "arch apply before the distro changes exits 0" ""
  echo ID=debian > "$root/etc/os-release"
  if unknown=$(${withoutArchOnly} 2>&1); then fail "an unknown distro makes the run exit 1" "$unknown"; fi
  has "an unknown distro is named" "$unknown" "distro 'debian' is not arch or fedora"
  [ -e "$root/etc/arch-only.conf" ] || fail "an unknown distro removes no file" "$unknown"
  has "an unknown distro keeps the file list" "$(cat "$root/var/lib/dotfiles/files")" /etc/arch-only.conf
  [ -z "$(recorded)" ] || fail "an unknown distro is not recorded" "$(recorded)"

  fresh ID=debian
  if unknown=$(${converging} 2>&1); then fail "an unknown distro on a fresh root exits 1" "$unknown"; fi
  has "an unknown distro skips package steps" "$unknown" "no package manager for distro 'debian', package steps skipped"
  [ -z "$(ls $FAKE/pkgs)" ] || fail "an unknown distro installs no package" "$(ls $FAKE/pkgs)"
  [ -e "$root/etc/net.conf" ] || fail "an unknown distro runs the steps for every distro" "$unknown"
  [ ! -e "$root/etc/arch-only.conf" ] || fail "an unknown distro skips arch-only steps" "$unknown"
  [ "$(cat "$root/etc/net.d/env")" = "unknown debian " ] || fail "a script on an unknown distro sees DISTRO=unknown" "$(cat "$root/etc/net.d/env" 2>&1)"
  has "a file an unknown distro installs is recorded" "$(cat "$root/var/lib/dotfiles/files")" /etc/net.conf
  echo ID=arch > "$root/etc/os-release"
  later=$(${onlyArchOnly} 2>&1) || fail "arch apply after an unknown run exits 0" "$later"
  [ ! -e "$root/etc/net.conf" ] || fail "a file an unknown distro installed is removed once no step declares it" "$later"

  fresh NAME=Mystery
  if unknown=$(${converging} 2>&1); then fail "an os-release with no ID exits 1" "$unknown"; fi
  has "an os-release with no ID is reported, not a crash" "$unknown" "distro 'not set' is not arch or fedora"
  rm "$root/etc/os-release"
  if unknown=$(${converging} 2>&1); then fail "a missing os-release exits 1" "$unknown"; fi
  has "a missing os-release is reported, not a crash" "$unknown" "distro 'not set' is not arch or fedora"

  fresh ID=nobara ID_LIKE=fedora VERSION_ID=43
  fedora=$(${converging} 2>&1) || fail "fedora apply exits 0" "$fedora"
  has "fedora installs with dnf" "$fedora" "dnf: installed tailscale"
  has "fedora installs the fedora package list" "$fedora" "dnf: installed dnf-only"
  [ "$(ls $FAKE/pkgs | tr '\n' ' ')" = "dnf-dnf-only dnf-hypr-only dnf-tailscale " ] || fail "fedora installs nothing with pacman" "$(ls $FAKE/pkgs)"
  [ ! -e "$root/etc/arch-only.conf" ] || fail "fedora skips arch-only steps" "$fedora"
  [ "$(cat "$root/etc/net.d/env")" = "fedora nobara 43" ] || fail "a script sees the family, the distro's own ID and VERSION_ID" "$(cat "$root/etc/net.d/env" 2>&1)"
  [ "$(recorded)" = ${converging} ] || fail "a clean fedora run records itself" "$(recorded)"
  has "a repository's package installs on fedora, so the repository came first" "$fedora" "dnf: installed hypr-only"
  repo=$root/etc/yum.repos.d/_$COPR.repo
  [ "$(ls "$root/etc/yum.repos.d")" = "_$COPR.repo" ] || fail "a COPR is written to the file dnf copr enable names" "$(ls "$root/etc/yum.repos.d")"
  [ "$(sed -n 's|^gpgkey=||p' "$repo")" = file://$key ] \
    || fail "the repository names the pinned key it installed" "$(cat "$repo" 2>&1)"
  grep -qx 'baseurl=https://repo.example.invalid/fedora-$releasever-$basearch/' "$repo" \
    || fail "the repository's baseurl is written as declared" "$(cat "$repo")"
  before=$(snapshot)
  : > $FAKE/fetches
  second=$(${converging} 2>&1) || fail "second fedora apply exits 0" "$second"
  [ -z "$(changes "$second")" ] || fail "second fedora apply reports no changes" "$second"
  [ "$before" = "$(snapshot)" ] || fail "second fedora apply changes nothing" "$(diff <(echo "$before") <(snapshot))"
  [ -z "$(fetches)" ] || fail "second fedora apply fetches no key" "$(fetches)"

  enabled() { printf '%s\n' "[$COPR]" 'name=Copr repo for hyprrepo' 'baseurl=https://repo.example.invalid/fedora-$releasever-$basearch/' 'gpgkey=https://keys.example.invalid/pinned.asc'; }
  enabled > "$repo"
  again=$(${converging} 2>&1) || fail "apply after dnf copr enable exits 0" "$again"
  [ "$(cat "$root"/etc/yum.repos.d/* | grep -cxF "[$COPR]")" = 1 ] || fail "a COPR enabled by dnf afterwards is still defined once" "$(grep -r . "$root/etc/yum.repos.d")"
  grep -qx "gpgkey=file://$key" "$repo" \
    || fail "a COPR enabled by dnf afterwards gets the pinned key back" "$(cat "$repo")"
  [ -z "$(find "$root/etc" -name '*.pre-nix')" ] || fail "a repository file and a key the program created are rewritten with no copy" "$(find "$root/etc" -name '*.pre-nix')"

  fresh ID=fedora VERSION_ID=43
  install -D -m 0644 $FAKE/other.asc "$root$key"
  replaced=$(${converging} 2>&1) || fail "apply over a wrong key at the key path exits 0" "$replaced"
  [ "$(fingerprints "$root$key")" = "$PINNED" ] || fail "a wrong key at the key path is replaced by the pinned one" "$(fingerprints "$root$key")"
  cmp -s $FAKE/other.asc "$root$key.pre-nix" || fail "a key that was already at the key path keeps one copy beside it" "$(ls -la "$(dirname "$root$key")")"
  has "a repository whose key path held a wrong key serves its package" "$replaced" "dnf: installed hypr-only"

  fresh ID=fedora VERSION_ID=43
  enabled > "$root/etc/yum.repos.d/elsewhere.repo"
  adopted=$(${converging} 2>&1) || fail "apply over a repository another file defines exits 0" "$adopted"
  [ "$(cd "$root/etc/yum.repos.d" && ls *.repo)" = elsewhere.repo ] || fail "a repository defined in another file is rewritten there, not defined twice" "$(ls "$root/etc/yum.repos.d")"
  [ "$(cat "$root/etc/yum.repos.d/elsewhere.repo.pre-nix" 2>&1)" = "$(enabled)" ] || fail "a repository file that was already there keeps one copy beside it" "$(ls "$root/etc/yum.repos.d")"
  grep -qx "gpgkey=file://$key" "$root/etc/yum.repos.d/elsewhere.repo" \
    || fail "a repository defined in another file gets the pinned key" "$(cat "$root/etc/yum.repos.d/elsewhere.repo")"

  fresh ID=fedora VERSION_ID=43
  enabled > "$root/etc/yum.repos.d/elsewhere.repo"
  { printf '%s\n' '[before]' 'baseurl=https://repo.example.invalid/before/' ""; enabled; printf '%s\n' "" '[after]' 'baseurl=https://repo.example.invalid/after/'; } > "$root/etc/yum.repos.d/second.repo"
  second=$(cat "$root/etc/yum.repos.d/second.repo")
  twice=$(${converging} 2>&1) || fail "apply over a repository two files define exits 0" "$twice"
  [ "$(cat "$root"/etc/yum.repos.d/*.repo | grep -cxF "[$COPR]")" = 1 ] || fail "a repository two files define is defined once afterwards" "$(grep -r . "$root/etc/yum.repos.d")"
  grep -qx "gpgkey=file://$key" "$root/etc/yum.repos.d/elsewhere.repo" || fail "a repository two files define is rewritten in the first of them" "$(cat "$root/etc/yum.repos.d/elsewhere.repo")"
  [ "$(cat "$root/etc/yum.repos.d/second.repo")" = "$(printf '%s\n' '[before]' 'baseurl=https://repo.example.invalid/before/' "" '[after]' 'baseurl=https://repo.example.invalid/after/')" ] \
    || fail "the other file loses that repository and keeps its own" "$(cat "$root/etc/yum.repos.d/second.repo")"
  [ "$(cat "$root/etc/yum.repos.d/second.repo.pre-nix" 2>&1)" = "$second" ] || fail "the other file keeps one copy from before" "$(ls "$root/etc/yum.repos.d")"
  has "a second definition that is removed is reported" "$twice" "/etc/yum.repos.d/second.repo"
  before=$(snapshot)
  again=$(${converging} 2>&1) || fail "second apply over a repository two files defined exits 0" "$again"
  [ -z "$(changes "$again")" ] && [ "$before" = "$(snapshot)" ] || fail "second apply over a repository two files defined changes nothing" "$again"

  fresh ID=fedora VERSION_ID=43
  ${vendor} > /dev/null 2>&1 || fail "apply of a repository that is not a COPR exits 0" "$(${vendor} 2>&1)"
  [ "$(ls "$root/etc/yum.repos.d")" = vendorrepo.repo ] || fail "a repository that is not a COPR is written to a file with its own name" "$(ls "$root/etc/yum.repos.d")"

  fresh ID=fedora VERSION_ID=43
  ${metadata} > /dev/null 2>&1 || fail "apply of a repository with signed metadata exits 0" "$(${metadata} 2>&1)"
  grep -qx repo_gpgcheck=1 "$root/etc/yum.repos.d/signedrepo.repo" \
    || fail "dnf is told to check the metadata signature of a repository that signs its metadata" "$(cat "$root/etc/yum.repos.d/signedrepo.repo" 2>&1)"
  grep -qx repo_gpgcheck=0 "$root/etc/yum.repos.d/plainrepo.repo" \
    || fail "dnf is not told to check a metadata signature the repository does not publish" "$(cat "$root/etc/yum.repos.d/plainrepo.repo" 2>&1)"

  fresh ID=fedora VERSION_ID=43
  install -m 0644 $FAKE/other.asc $FAKE/web/pinned.asc
  if result=$(${converging} 2>&1); then fail "a key that is not the pinned one makes the fedora run exit 1" "$result"; fi
  [ -z "$(ls "$root/etc/yum.repos.d")" ] || fail "a refused fedora repository writes no file" "$(ls "$root/etc/yum.repos.d")"
  [ -z "$(find "$root/etc" -name '*.pre-nix')" ] || fail "a refused fedora repository copies no file" "$(find "$root/etc" -name '*.pre-nix')"
  [ ! -e "$root/etc/hypr.conf" ] || fail "a fedora step whose package needs a refused repository is skipped" "$result"
  [ -e "$root/etc/net.conf" ] || fail "a refused fedora repository does not stop other steps" "$result"

  for distro in arch fedora; do
    fresh ID=$distro
    touch $FAKE/resigned
    if result=$(${converging} 2>&1); then fail "a package whose signature fails makes the $distro run exit 1" "$result"; fi
    [ ! -e "$root/etc/hypr.conf" ] || fail "a step whose package fails its signature is skipped on $distro" "$result"
    [ -e "$root/etc/net.conf" ] || fail "a package whose signature fails does not stop other steps on $distro" "$result"
  done

  fresh ID=fedora VERSION_ID=43
  touch $FAKE/offline
  if result=$(${converging} 2>&1); then fail "dnf with no network makes the run exit 1" "$result"; fi
  [ "$(calls | wc -l)" = 1 ] || fail "dnf with no network is called once, not once more for each step" "$(calls)"
  case $result in *"look stale"*) fail "dnf with no network is not called a stale database" "$result" ;; esac
  [ ! -e "$root/etc/net.conf" ] && [ ! -e "$root/etc/hypr.conf" ] || fail "dnf with no network skips every step with packages" "$result"

  fresh ID=arch
  echo 1.0-5 > $FAKE/pkgs/pacman-tailscale
  newer=$(${converging} 2>&1) || fail "apply beside a package installed at a version the repository does not have exits 0" "$newer"
  [ "$(cat $FAKE/pkgs/pacman-tailscale)" = 1.0-5 ] || fail "a package installed at a version the repository does not have keeps it" "$newer"
  case $newer in *downgrading*) fail "a package installed at a version the repository does not have is not downgraded" "$newer" ;; esac

  fresh ID=arch
  echo jq-git > $FAKE/provides/pacman-jq
  echo 1.0-5 > $FAKE/pkgs/pacman-tailscale
  selected=$(${converging} 2>&1) || fail "apply beside an installed provider and a locally newer package exits 0" "$selected"
  [ ! -e $FAKE/pkgs/pacman-jq ] || fail "a name an installed package provides is not installed" "$selected"
  [ "$(calls | grep '^-S ')" = "-S --needed --noconfirm hypr-only" ] || fail "the install call names only what nothing installed provides" "$(calls)"
  has "a missing package is installed" "$selected" "pacman: installed hypr-only"
  [ -e "$root/etc/net.conf" ] && [ -e $FAKE/units/tailscaled.service ] && [ "$(recorded)" = ${converging} ] \
    || fail "a step whose packages are all provided is applied" "$selected"
  : > $FAKE/calls
  again=$(${converging} 2>&1) || fail "the run with every name provided exits 0" "$again"
  [ -z "$(calls)" ] || fail "a run with every name provided makes no install call" "$(calls)"

  fresh ID=arch
  echo tailscale-git > $FAKE/provides/pacman-tailscale
  if result=$(${brokenPackage} 2>&1); then fail "a failed package beside a provided one makes the run exit 1" "$result"; fi
  [ "$(calls | grep '^-S ')" = "$(printf '%s\n' "-S --needed --noconfirm broken-package hypr-only" "-S --needed --noconfirm broken-package" "-S --needed --noconfirm hypr-only")" ] \
    || fail "one call for every missing package, then one for each step, each naming only what is missing" "$(calls)"
  has "the step that misses a package that does not exist is skipped" "$result" "dotfiles-root-apply: packages for blocked failed"
  [ -e "$root/etc/hypr.conf" ] && [ ! -e "$root/etc/net.conf" ] && [ ! -e $FAKE/pkgs/pacman-tailscale ] \
    || fail "the other step installs its package on its own, and the provided one stays uninstalled" "$result"

  fresh ID=arch
  touch $FAKE/db-unreadable
  if result=$(${converging} 2>&1); then fail "a package database that cannot be read makes the run exit 1" "$result"; fi
  has "a package database that cannot be read is named" "$result" "the local package database could not say which packages are installed"
  [ -z "$(calls)" ] || fail "a package database that cannot be read syncs and installs nothing" "$(calls)"
  has "a package database that cannot be read skips every step with packages" "$result" "dotfiles-root-apply: the package manager failed without naming a package"
  [ ! -e "$root/etc/net.conf" ] || fail "a package database that cannot be read applies no step with packages" "$result"

  fresh ID=fedora VERSION_ID=43
  echo tailscale-git > $FAKE/provides/dnf-tailscale
  selected=$(${converging} 2>&1) || fail "fedora apply beside an installed provider exits 0" "$selected"
  [ ! -e $FAKE/pkgs/dnf-tailscale ] || fail "a name an installed package provides is not installed on fedora" "$selected"
  [ "$(calls)" = "dnf install -y hypr-only dnf-only" ] || fail "the fedora install call names only what nothing installed provides" "$(calls)"
  : > $FAKE/calls
  ${converging} > /dev/null 2>&1 || fail "the fedora run with every name provided exits 0" ""
  [ -z "$(calls)" ] || fail "a fedora run with every name provided makes no install call" "$(calls)"

  fresh ID=arch
  ${converging} > /dev/null 2>&1 || fail "the clean run before a failed package exits 0" ""
  rm "$root/etc/hypr-ran" $FAKE/units/*
  echo stale > "$root/etc/net.conf"
  : > $FAKE/calls
  if result=$(${brokenPackage} 2>&1); then fail "a failed package makes the run exit 1" "$result"; fi
  [ "$(calls)" = "$(printf '%s\n' "-S --needed --noconfirm broken-package" "-S --needed --noconfirm broken-package")" ] \
    || fail "a failure that names a package is retried once for each step that still misses a package, naming only what it misses" "$(calls)"
  has "a failed package names its step" "$result" "dotfiles-root-apply: packages for blocked failed"
  case $result in *"look stale"*) fail "a package that does not exist is not called a stale database" "$result" ;; esac
  [ "$(cat "$root/etc/net.conf")" = stale ] || fail "a step whose package failed has its files skipped" "$result"
  [ ! -e $FAKE/units/tailscaled.service ] || fail "a step whose package failed has its units skipped" "$result"
  has "a step whose package failed has its script skipped" "$result" "dotfiles-root-apply: packages for blocked failed, so its files, units and script are skipped"
  case $result in *"root step: blocked"*) fail "a step whose package failed runs no script" "$result" ;; esac
  has "a file a skipped step installed earlier stays on the list" "$(cat "$root/var/lib/dotfiles/files")" /etc/net.conf
  [ -e "$root/etc/hypr.conf" ] && [ -e $FAKE/units/hypr.service ] && [ -e "$root/etc/hypr-ran" ] \
    || fail "another step's files, units and script still apply" "$result"
  [ -e $FAKE/units/shared.service ] || fail "a unit a skipped step shares with another step is enabled" "$result"
  has "a failed package says it will run again" "$result" "Not recorded, so the next switch runs it again."
  [ -z "$(recorded)" ] || fail "a failed package is not recorded" "$(recorded)"
  case $result in *"disabled"*) fail "a unit that a step skipped this run declares is not disabled" "$result" ;; esac
  rerun=$(${converging} 2>&1) || fail "the next run, with the package fixed, exits 0" "$rerun"
  [ "$(cat "$root/etc/net.conf")" = net ] || fail "the next run applies the skipped step's file" "$rerun"

  echo stale | tee "$root/etc/net.conf" > "$root/etc/arch-only.conf"
  : > $FAKE/calls
  rm $FAKE/pkgs/pacman-jq
  touch $FAKE/locked
  if result=$(${converging} 2>&1); then fail "a locked package database makes the run exit 1" "$result"; fi
  [ "$(calls | wc -l)" = 1 ] || fail "a locked package database is met once, not once more for each step" "$(calls)"
  has "a failure that names no package is reported once" "$result" "dotfiles-root-apply: the package manager failed without naming a package"
  [ "$(cat "$root/etc/net.conf")" = stale ] || fail "a failure that names no package skips every step with packages" "$result"
  [ "$(cat "$root/etc/arch-only.conf")" = arch ] || fail "a failure that names no package does not stop a step with no packages" "$result"
  [ -z "$(recorded)" ] || fail "a failure that names no package is not recorded" "$(recorded)"

  rm $FAKE/locked
  ${converging} > /dev/null 2>&1 || fail "the clean run before a full disk exits 0" ""
  [ "$(cat $FAKE/locale)" = C ] || fail "pacman is run in the C locale, so its messages are the ones the program reads" "$(cat $FAKE/locale)"
  : > $FAKE/calls
  rm $FAKE/pkgs/pacman-jq
  touch $FAKE/full
  if result=$(${converging} 2>&1); then fail "a full disk makes the run exit 1" "$result"; fi
  [ "$(calls | wc -l)" = 1 ] || fail "a full disk is met once" "$(calls)"
  has "a full disk is reported as a failure over no one package" "$result" "dotfiles-root-apply: the package manager failed without naming a package"

  rm $FAKE/full
  ${converging} > /dev/null 2>&1 || fail "the clean run before a stale database exits 0" ""
  rm $FAKE/pkgs/pacman-jq
  echo jq > $FAKE/gone
  : > $FAKE/calls
  if result=$(${converging} 2>&1); then fail "a package the mirror no longer has makes the run exit 1" "$result"; fi
  [ "$(grep -c '^dotfiles-root-apply: .*look stale' <<< "$result")" = 1 ] || fail "a 404 from the mirror is called a stale database, once" "$result"
  has "a stale database names the upgrade to run on arch" "$(grep 'look stale' <<< "$result")" "sudo pacman -Syu"
  has "a stale database says to switch again" "$(grep 'look stale' <<< "$result")" "switch again"
  [ "$(syncs)" = 0 ] || fail "the program does not sync for a stale database" "$(calls)"
  has "the step that needs the package the mirror no longer has is skipped" "$result" "dotfiles-root-apply: packages for net failed"
  [ "$(calls)" = "$(printf '%s\n' "-S --needed --noconfirm jq" "-S --needed --noconfirm jq")" ] \
    || fail "a package the mirror no longer has is retried once, for the one step that misses it" "$(calls)"

  touch $FAKE/offline
  : > $FAKE/calls
  if result=$(${converging} 2>&1); then fail "a package download with no network makes the run exit 1" "$result"; fi
  has "pacman cannot reach the mirror for a package" "$result" "Could not resolve host"
  [ "$(calls | wc -l)" = 1 ] || fail "a package download with no network is met once, not once more for each step" "$(calls)"
  case $result in *"look stale"*) fail "a package download with no network is not called a stale database" "$result" ;; esac

  fresh ID=fedora VERSION_ID=43
  echo dnf-only > $FAKE/gone
  touch $FAKE/offline
  if result=$(${converging} 2>&1); then fail "a fedora package download with no network makes the run exit 1" "$result"; fi
  has "dnf cannot reach the mirror for a package" "$result" "Failed to download packages"
  [ "$(calls | wc -l)" = 1 ] || fail "a fedora package download with no network is met once, not once more for each step" "$(calls)"
  case $result in *"look stale"*) fail "a fedora package download with no network is not called a stale database" "$result" ;; esac

  fresh ID=fedora VERSION_ID=43
  echo dnf-only > $FAKE/gone
  if result=$(${converging} 2>&1); then fail "a package the mirror no longer has makes the fedora run exit 1" "$result"; fi
  [ "$(grep -c '^dotfiles-root-apply: .*look stale' <<< "$result")" = 1 ] || fail "a 404 from the mirror is called a stale database on fedora, once" "$result"
  has "a stale database names the upgrade to run on fedora" "$(grep 'look stale' <<< "$result")" "sudo dnf upgrade --refresh"
  [ ! -e "$root/etc/net.conf" ] && [ -e "$root/etc/hypr.conf" ] || fail "only the fedora step that needs the package the mirror no longer has is skipped" "$result"

  fresh ID=fedora VERSION_ID=43
  ${converging} > /dev/null 2>&1 || fail "the clean fedora run before a busy rpm exits 0" ""
  [ "$(cat $FAKE/locale)" = C ] || fail "dnf is run in the C locale, so its messages are the ones the program reads" "$(cat $FAKE/locale)"
  : > $FAKE/calls
  rm $FAKE/pkgs/dnf-dnf-only
  touch $FAKE/busy
  if result=$(${converging} 2>&1); then fail "a busy rpm makes the run exit 1" "$result"; fi
  [ "$(calls | wc -l)" = 1 ] || fail "a busy rpm is met once" "$(calls)"
  has "a busy rpm is reported as a failure over no one package" "$result" "dotfiles-root-apply: the package manager failed without naming a package"

  fresh ID=fedora VERSION_ID=43
  touch $FAKE/metadata-gone $FAKE/busy
  if result=$(${converging} 2>&1); then fail "a busy rpm beside a repository whose metadata is gone makes the run exit 1" "$result"; fi
  has "dnf reports a 404 for a repository's metadata" "$result" "Status code: 404 for https://copr.example.invalid/results/fixture/gone/fedora-43-x86_64/repodata/repomd.xml"
  case $result in *"look stale"*) fail "a 404 for a repository's metadata is not called a stale database" "$result" ;; esac
  [ "$(calls | wc -l)" = 1 ] || fail "a 404 for a repository's metadata does not make a failure over no one package retried for each step" "$(calls)"

  for refusal in check run; do
    fresh ID=fedora VERSION_ID=43
    echo $refusal > $FAKE/rpm-refuses
    if result=$(${converging} 2>&1); then fail "a package rpm refuses ($refusal) makes the run exit 1" "$result"; fi
    has "a package rpm refuses ($refusal) names its step" "$result" "dotfiles-root-apply: packages for net failed"
    [ ! -e "$root/etc/net.conf" ] && [ -e "$root/etc/hypr.conf" ] || fail "only the step that needs the package rpm refuses ($refusal) is skipped" "$result"
    case $result in *"look stale"*) fail "a package rpm refuses ($refusal) is not called a stale database" "$result" ;; esac
  done

  fresh ID=arch
  ${converging} > /dev/null 2>&1 || fail "the clean run before a failing one exits 0" ""
  if result=$(${failing} 2>&1); then fail "a failed step makes the run exit 1" "$result"; fi
  has "a failed unit is reported" "$result" "enable missing.service failed, continuing"
  has "a failed script is reported" "$result" "script broken failed, continuing"
  [ -e $FAKE/units/tailscaled.service ] || fail "a failed unit does not stop the next unit" "$result"
  [ -e "$root/etc/later-ran" ] || fail "a failed script does not stop the next script" "$result"
  has "a failed run says it will run again" "$result" "Not recorded, so the next switch runs it again."
  [ -z "$(recorded)" ] || fail "a failed run clears the record of the clean run before it" "$(recorded)"

  fresh ID=arch
  ${converging} > /dev/null 2>&1 || fail "the run that enables units exits 0" ""
  [ "$(${withoutArchOnly} --retiring 2>&1)" = "" ] || fail "a program that still declares every unit it enabled retires none" "$(${withoutArchOnly} --retiring 2>&1)"
  [ "$(${onlyArchOnly} --retiring 2>&1 | sort | tr '\n' ' ')" = "hypr.service shared.service tailscaled.service " ] \
    || fail "a program lists the units an earlier run enabled that it no longer declares" "$(${onlyArchOnly} --retiring 2>&1)"
  dropped=$(${onlyArchOnly} 2>&1) || fail "a run that no longer declares units exits 0" "$dropped"
  for unit in hypr.service shared.service tailscaled.service; do
    has "a unit the program enabled and no longer declares is disabled and stopped" "$dropped" "disabled and stopped $unit"
    [ ! -e "$FAKE/units/$unit" ] || fail "$unit is no longer enabled" "$dropped"
  done
  [ -z "$(${onlyArchOnly} --retiring 2>&1)" ] || fail "a unit that was disabled is not listed again" "$(${onlyArchOnly} --retiring 2>&1)"
  [ -e "$FAKE/pkgs/pacman-tailscale" ] || fail "packages stay when their step goes" ""
  again=$(${onlyArchOnly} 2>&1) || fail "the run after units were disabled exits 0" "$again"
  case $again in *"disabled"*) fail "a unit is disabled once" "$again" ;; esac

  upgrading=$(awk '{ for (i = 2; i <= NF; i++) if ($i ~ /^-[A-Za-z]*u/ || $i == "--sysupgrade" || ($1 == "dnf" && ($i ~ /^(upgrade|update|distro-sync|upgrade-minimal|update-minimal)$/))) { print; next } }' $FAKE/every-call)
  [ -s $FAKE/every-call ] && [ -z "$upgrading" ] || fail "no pacman or dnf call in any case asks for an upgrade" "$upgrading"

  [ "$failures" = 0 ]
  touch $out
''
