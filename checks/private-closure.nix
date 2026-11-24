{ dot, pkgs }:
let
  inherit (dot) lib;
  source = builtins.path { path = ../private-stub; name = "private-source"; };
  machines = dot.machinesFrom source;
  generation = machines.stub-work-laptop;
  copied = {
    stub-work-laptop = pkgs.closureInfo { rootPaths = [ generation.build ]; };
  } // lib.genAttrs [ "stub-thin-mac" "stub-work-mac-server" ] (name: pkgs.runCommand "derivation-closure-${name}" { } ''
    echo ${builtins.unsafeDiscardOutputDependency machines.${name}.build.drvPath} > todo
    : > $TMPDIR/store-paths
    while [ -s todo ]; do
      grep -vxFf $TMPDIR/store-paths todo | sort -u > next || true
      cat next >> $TMPDIR/store-paths
      grep '\.drv$' next > drvs || true
      xargs -r grep -ohE '/nix/store/[0-9a-z]{32}-[A-Za-z0-9+._?=-]+' < drvs > refs || true
      sort -u refs | while read -r path; do [ ! -e "$path" ] || echo "$path"; done > todo
    done
    mkdir $out
    sort -u $TMPDIR/store-paths > $out/store-paths
  '');
in
pkgs.runCommand "check-private-closure" { } ''
  fail() { echo "FAIL $1"; exit 1; }
  grep -qxF ${generation.build} ${copied.stub-work-laptop}/store-paths || fail "the copied closure lists the generation itself"
  [ "$(cat ${generation.build}/dotfiles-build-host)" = ${lib.escapeShellArg generation.private.buildHost} ] \
    || fail "the generation names the build host its machine entry gives"
  ${lib.concatMapStrings (name: ''
    grep -qxF ${builtins.unsafeDiscardStringContext machines.${name}.build.drvPath} ${copied.${name}}/store-paths \
      || fail "the derivation closure dot copies to ${name} lists the system's derivation"
  '') [ "stub-thin-mac" "stub-work-mac-server" ]}
  cd ${source}
  find . -type f -printf '%s %P\n' > $TMPDIR/private-files
  [ "$(wc -l < $TMPDIR/private-files)" -gt 2 ] || fail "the private input copy has its identity and machine entries"
  ${lib.concatStrings (lib.mapAttrsToList (name: closure: ''
    while read -r size file; do
      copy=$(xargs -a ${closure}/store-paths -I@ find @ -type f -size "''${size}c" -exec cmp -s "$file" {} \; -print | head -n 1)
      [ -z "$copy" ] || fail "the closure dot copies to ${name} holds the private input's $file, as $copy"
    done < $TMPDIR/private-files
  '') copied)}
  touch $out
''
