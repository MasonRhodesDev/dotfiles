{ lib, pkgs, stub, evalHome }:
let
  stepOf = name: stub.${name}.configuration.config.dotfiles.root.build-trust or null;
  program = name: "${(evalHome { modules = [{ dotfiles.root.build-trust = stepOf name; }]; }).config.dotfiles.rootApplyScratch}/bin/dotfiles-root-apply";
  builder = "stub-headless";
  peer = "stub-gaming-desktop";
  target = "stub-work-laptop";
  publicKeys = (import ../private-stub/identity.nix).buildHosts;
  keyName = name: lib.head (lib.splitString ":" publicKeys.${name});
  opted = lib.attrNames (lib.filterAttrs (name: m: m.platform == "linux" && stepOf name != null) stub);
  bystanders = lib.attrNames (lib.filterAttrs (name: m: m.platform == "linux" && stepOf name == null) stub);
  cacheKey = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
  derivation = name: ''derivation { name = "${name}"; system = "${pkgs.stdenv.hostPlatform.system}"; builder = "/bin/sh"; args = [ "-c" "echo ${name} > $out" ]; }'';
in
pkgs.runCommand "check-build-trust" { nativeBuildInputs = [ pkgs.nix ]; } ''
  fail() { echo "FAIL $1"; [ -z "''${2:-}" ] || printf '%s\n' "$2"; exit 1; }
  [ ${lib.escapeShellArg (toString opted)} = ${lib.escapeShellArg "${peer} ${builder} ${target}"} ] \
    || fail "only the build hosts and the machine that names a build host get the step, not: ${toString opted}"
  [ -n ${lib.escapeShellArg (toString bystanders)} ] || fail "a Linux stub that is no build host and names none is left to get no trust config"

  export HOME=$TMPDIR/home FAKE=$TMPDIR/fake
  mkdir -p $HOME $FAKE/bin
  printf '#!/bin/sh\necho "systemctl $*" >> "$FAKE/calls"\n' > $FAKE/bin/systemctl
  chmod +x $FAKE/bin/systemctl
  export PATH=$FAKE/bin:$PATH
  base='build-users-group =
  sandbox = false
  substituters =
  experimental-features = nix-command
  '
  mkroot() {
    mkdir -p $1/etc/nix
    echo ID=arch > $1/etc/os-release
    printf '%s' "$base" | sed 's/^  //' > $1/etc/nix/nix.conf
  }
  apply() { DOTFILES_ROOT_PREFIX=$1 $2 2>&1; }
  restarts() { grep -c "try-restart nix-daemon.service" $FAKE/calls 2>/dev/null || true; }
  conf() { NIX_CONF_DIR=$1/etc/nix nix "''${@:2}"; }
  key=$TMPDIR/bh/etc/nix/dotfiles-signing.sec
  peerKey=$TMPDIR/peer/etc/nix/dotfiles-signing.sec

  nix --extra-experimental-features nix-command key generate-secret --key-name ${keyName builder} > $TMPDIR/build-host.sec
  generated=$(nix --extra-experimental-features nix-command key convert-secret-to-public < $TMPDIR/build-host.sec)
  nix --extra-experimental-features nix-command key generate-secret --key-name ${keyName peer} > $TMPDIR/peer.sec
  peerGenerated=$(nix --extra-experimental-features nix-command key convert-secret-to-public < $TMPDIR/peer.sec)
  render() {
    local to=$TMPDIR/rendered/$1 file copy
    mkdir -p $to
    cp $2 $to/program
    for file in $(grep -oE '/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+' $2 | sort -u); do
      [ -f $file ] && grep -qF -e ${publicKeys.${builder}} -e ${publicKeys.${peer}} $file || continue
      copy=$to/''${file#/nix/store/}
      sed "s|${publicKeys.${builder}}|$generated|g; s|${publicKeys.${peer}}|$peerGenerated|g" $file > $copy
      sed -i "s|$file|$copy|g" $to/program
    done
    chmod +x $to/program
    grep -qrF -e "$generated" -e "$peerGenerated" $to || fail "the $1 program is rendered from the key pairs this check made" "$(ls $to)"
    ! grep -qrF -e ${publicKeys.${builder}} -e ${publicKeys.${peer}} $to || fail "the $1 program names no stub key"
  }
  render build-host ${program builder}
  render peer ${program peer}
  render target ${program target}
  buildHost=$TMPDIR/rendered/build-host/program peerHost=$TMPDIR/rendered/peer/program target=$TMPDIR/rendered/target/program
  trustsAll() {
    local trusted
    trusted=$(conf $1 config show trusted-public-keys)
    grep -qF ${cacheKey} <<< "$trusted" || fail "$2 still trusts cache.nixos.org" "$trusted"
    grep -qF "$generated" <<< "$trusted" && grep -qF "$peerGenerated" <<< "$trusted" || fail "$2 trusts every build host's key" "$trusted"
    [ "$(conf $1 config show require-sigs)" = true ] || fail "$2 still requires signatures"
  }

  mkroot $TMPDIR/bh
  if result=$(apply $TMPDIR/bh $buildHost); then fail "a build host without its key fails the root program" "$result"; fi
  grep -qF "signs nothing it builds: /etc/nix/dotfiles-signing.sec is missing. The cleanup runbook's build host step B1 makes it" <<< "$result" || fail "a build host without its key says so, and names the step that makes it" "$result"
  grep -qF "step B4 signs what was built in between" <<< "$result" || fail "a key problem names the step that signs what was built meanwhile" "$result"
  [ -z "$(conf $TMPDIR/bh config show secret-key-files)" ] || fail "a build host without its key names no secret-key-files"
  unsigned=$(conf $TMPDIR/bh build --store "local?root=$TMPDIR/bh-store" --no-link --print-out-paths --expr ${lib.escapeShellArg (derivation "unsigned")}) \
    || fail "a build host without its key still builds"

  conf $TMPDIR/bh key generate-secret --key-name other-1 > $key
  chmod 600 $key
  if result=$(apply $TMPDIR/bh $buildHost); then fail "a build host with another key fails the root program" "$result"; fi
  grep -qF "is not the key whose public half identity.buildHosts.${builder} names. The cleanup runbook's build host step B2" <<< "$result" || fail "a build host with another key says so, and names the step that puts its public half there" "$result"

  install -m 644 $TMPDIR/build-host.sec $key
  if result=$(apply $TMPDIR/bh $buildHost); then fail "a key others can read fails the root program" "$result"; fi
  grep -qF "must be mode 0600 and owned by root. sudo chown root:root and sudo chmod 600 it" <<< "$result" || fail "a key others can read is named, with the commands that fix it" "$result"
  chmod 600 $key

  before=$(restarts)
  result=$(apply $TMPDIR/bh $buildHost) || fail "a build host with its key applies" "$result"
  ! grep -qF "$(cut -d: -f2 $key)" <<< "$result" || fail "the root program never prints the secret key"
  [ "$(restarts)" -gt "$before" ] || fail "the nix daemon restarts when it gains its signing key" "$(cat $FAKE/calls)"
  grep -qxF '!include dotfiles.conf' $TMPDIR/bh/etc/nix/nix.conf || fail "nix.conf includes dotfiles.conf where there is no nix.custom.conf" "$(cat $TMPDIR/bh/etc/nix/nix.conf)"
  [ "$(conf $TMPDIR/bh config show secret-key-files)" = "$key" ] || fail "nix on the build host signs with its key" "$(conf $TMPDIR/bh config show secret-key-files)"
  signed=$(conf $TMPDIR/bh build --store "local?root=$TMPDIR/bh-store" --no-link --print-out-paths --expr ${lib.escapeShellArg (derivation "signed")})
  conf $TMPDIR/bh path-info --store "local?root=$TMPDIR/bh-store" --sigs $signed | grep -qF " ${keyName builder}:" \
    || fail "what the build host builds is signed before anything copies it" "$(conf $TMPDIR/bh path-info --store "local?root=$TMPDIR/bh-store" --sigs $signed)"

  mkroot $TMPDIR/peer
  install -m 600 $TMPDIR/peer.sec $peerKey
  result=$(apply $TMPDIR/peer $peerHost) || fail "a second build host with its key applies" "$result"
  peerSigned=$(conf $TMPDIR/peer build --store "local?root=$TMPDIR/peer-store" --no-link --print-out-paths --expr ${lib.escapeShellArg (derivation "peer-signed")})
  conf $TMPDIR/peer copy --from "local?root=$TMPDIR/bh-store" --to "local?root=$TMPDIR/peer-store" $signed \
    || fail "a build host accepts what another build host signed"
  conf $TMPDIR/bh copy --from "local?root=$TMPDIR/peer-store" --to "local?root=$TMPDIR/bh-store" $peerSigned \
    || fail "the other build host accepts what the second one signed"
  trustsAll $TMPDIR/bh "a build host"
  trustsAll $TMPDIR/peer "a second build host"
  if result=$(conf $TMPDIR/peer copy --from "local?root=$TMPDIR/bh-store" --to "local?root=$TMPDIR/peer-store" $unsigned 2>&1); then
    fail "a build host refuses what another built before it had its key" "$result"
  fi

  mkroot $TMPDIR/target
  printf '!include nix.custom.conf\n' >> $TMPDIR/target/etc/nix/nix.conf
  printf '# written by an installer\n' > $TMPDIR/target/etc/nix/nix.custom.conf
  cp $TMPDIR/target/etc/nix/nix.conf $TMPDIR/nix.conf.before
  result=$(apply $TMPDIR/target $target) || fail "a machine that names a build host applies" "$result"
  cmp -s $TMPDIR/nix.conf.before $TMPDIR/target/etc/nix/nix.conf || fail "where nix.conf includes nix.custom.conf, nix.conf is left as it is"
  grep -qxF '!include dotfiles.conf' $TMPDIR/target/etc/nix/nix.custom.conf || fail "nix.custom.conf includes dotfiles.conf" "$(cat $TMPDIR/target/etc/nix/nix.custom.conf)"
  [ ! -e $TMPDIR/target/etc/nix/dotfiles-signing.conf ] || fail "a machine that is not a build host signs nothing"
  trustsAll $TMPDIR/target "the machine that names a build host"

  conf $TMPDIR/target copy --from "local?root=$TMPDIR/bh-store" --to "local?root=$TMPDIR/target-store" $signed \
    || fail "the machine accepts what the build host signed"
  if result=$(conf $TMPDIR/target copy --from "local?root=$TMPDIR/bh-store" --to "local?root=$TMPDIR/target-store" $unsigned 2>&1); then
    fail "the machine refuses what the build host built before it had its key" "$result"
  fi
  grep -qF "lacks a signature by a trusted key" <<< "$result" || fail "the refusal is nix's signature check" "$result"

  before=$(restarts)
  result=$(apply $TMPDIR/target $target) && result=$(apply $TMPDIR/bh $buildHost) || fail "a second run applies" "$result"
  [ "$(restarts)" = "$before" ] || fail "a second run with nothing changed leaves the nix daemon running" "$(cat $FAKE/calls)"
  [ "$(grep -cxF '!include dotfiles.conf' $TMPDIR/target/etc/nix/nix.custom.conf)" = 1 ] || fail "a second run adds no second include"

  rm $key
  if result=$(apply $TMPDIR/bh $buildHost); then fail "a build host whose key is gone fails the root program" "$result"; fi
  [ ! -e $TMPDIR/bh/etc/nix/dotfiles-signing.conf ] || fail "a build host whose key is gone stops naming it, so its builds still go through"
  conf $TMPDIR/bh build --store "local?root=$TMPDIR/bh-store" --no-link --expr ${lib.escapeShellArg (derivation "after")} || fail "a build host whose key is gone still builds"
  touch $out
''
