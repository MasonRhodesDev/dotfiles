let
  script = root: ''
    conf=${root}/etc/bluetooth/main.conf
    if [ ! -f "$conf" ]; then
        echo "$conf not present, skipping"
        exit 0
    fi

    changed=0
    missing=()
    ensure() {
        local key=$1 line=$2 edit
        grep -qxF "$line" "$conf" && return 0
        if grep -Eq "^$key *=" "$conf"; then
            edit="s/^$key *=.*/$line/"
        elif grep -Eq "^# *$key *=" "$conf"; then
            edit="0,/^# *$key *=.*/s//$line/"
        else
            missing+=("$key")
            return 0
        fi
        keep-original "$conf"
        sed -i -E "$edit" "$conf"
        changed=1
    }
    ensure JustWorksRepairing 'JustWorksRepairing = always'
    ensure AutoEnable 'AutoEnable=true'

    if [ "$changed" = 1 ]; then
        echo "$conf: JustWorksRepairing and AutoEnable set"
        systemctl try-restart bluetooth.service || true
    fi
    if [ ''${#missing[@]} != 0 ]; then
        echo "warning: $conf has no line for ''${missing[*]}; add it to the right section by hand" >&2
    fi
  '';
in
{
  name = "Bluetooth controller pairing";
  description = "BlueZ main.conf tweak for Xbox controller re-pairing.";
  platforms = [ "linux" ];
  when.hardware = "xbox-controller";

  linux.root.script = script "";

  checks = { pkgs, keepOriginal, ... }: {
    xbox-bluetooth-conf = pkgs.runCommand "xbox-bluetooth-conf" { } ''
      export ROOT=$TMPDIR/root DOTFILES_STATE=$TMPDIR/root/var/lib/dotfiles PATH=${keepOriginal}/bin:$PWD/bin:$PATH
      conf=$ROOT/etc/bluetooth/main.conf
      mkdir -p bin "$(dirname "$conf")" "$DOTFILES_STATE"
      printf '#!/bin/sh\necho "$*" >> "$ROOT/systemctl"\n' > bin/systemctl
      chmod +x bin/systemctl
      step() { ${pkgs.runtimeShell} -euo pipefail ${pkgs.writeText "xbox-step" (script "$ROOT")} 2>&1; }
      failures=0
      fail() { echo "FAIL $1"; ls -la "$(dirname "$conf")"; cat "$conf" 2>/dev/null; failures=$((failures + 1)); }
      shipped='[General]
      #JustWorksRepairing = never

      [Policy]
      #AutoEnable=true'

      printf '%s\n' "$shipped" > "$conf"
      step > /dev/null || fail "BlueZ's own file: the step succeeds"
      grep -qx 'JustWorksRepairing = always' "$conf" && grep -qx 'AutoEnable=true' "$conf" || fail "BlueZ's own file gets both lines"
      [ "$(cat "$conf.pre-nix" 2>&1)" = "$shipped" ] || fail "the file as BlueZ shipped it is kept beside the edited one"
      [ "$(cat "$ROOT/systemctl")" = "try-restart bluetooth.service" ] || fail "bluetooth is restarted once after the edit"

      before=$(cat "$conf")
      said=$(step) || fail "a file the step already edited: the step succeeds"
      [ "$(cat "$conf")" = "$before" ] && [ -z "$said" ] || fail "a file the step already edited is left alone"

      sed -i 's/^AutoEnable=true/AutoEnable=false/' "$conf"
      step > /dev/null || fail "a file edited since: the step succeeds"
      grep -qx 'AutoEnable=true' "$conf" && [ "$(cat "$conf.pre-nix")" = "$shipped" ] || fail "a later edit does not replace the copy"

      rm "$conf" "$conf.pre-nix"
      printf '%s\n' '[General]' 'JustWorksRepairing = always' '[Policy]' 'AutoEnable=true' > "$conf"
      step > /dev/null || fail "a file that needs no edit: the step succeeds"
      [ ! -e "$conf.pre-nix" ] || fail "a file that needs no edit gets no copy"

      rm "$conf"
      step > /dev/null || fail "no main.conf: the step succeeds"
      [ ! -e "$conf" ] || fail "no main.conf: none is created"

      [ "$failures" = 0 ]
      touch $out
    '';
  };

  inventory = {
    scripts = [
      {
        id = "54-bluetooth-tweaks";
        root = true;
      }
    ];
  };
}
