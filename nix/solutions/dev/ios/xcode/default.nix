let
  pin = {
    xcode = "27.2.0";
    runtime = "iOS 27.2";
  };
in
{
  name = "Xcode";
  description = "xcodes, the pinned Xcode and its iOS simulator runtime, selected with xcode-select, its license accepted and its first-launch setup run. The first download needs the owner's Apple ID once; until xcodes has that login, activation prints the step and goes on.";
  platforms = [ "darwin" ];

  darwin.system = { lib, pkgs, machine, ... }:
    let
      asUser = pkgs.writeShellScript "as-${machine.user.name}" ''
        exec launchctl asuser "$(id -u ${machine.user.name})" sudo -u ${machine.user.name} --set-home "$@"
      '';
    in
    {
      environment.systemPackages = [ pkgs.xcodes ];
      system.activationScripts.postActivation.text = lib.mkAfter ''
        echo "setting up Xcode ${pin.xcode}..." >&2
        ${import ./setup.nix pkgs} ${pkgs.xcodes}/bin/xcodes ${asUser} ${machine.user.name} ${lib.escapeShellArg machine.user.home} ${pin.xcode} ${lib.escapeShellArg pin.runtime} \
          || echo "xcode: the Xcode setup stopped early; switch again to retry it"
      '';
    };

  checks = { pkgs, ... }: {
    xcode-setup = pkgs.runCommand "check-xcode-setup" { } ''
      set -u
      fakes=$TMPDIR/fakes
      mkdir -p "$fakes"

      cat > "$fakes/xcodes" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "xcodes $*" >> "$STATE/calls"
      case "$1 $2" in
        "installed "*) [ -d "$APPS/Xcode-$2.app" ] || { echo "$2 is not installed" >&2; exit 1; }; echo "$APPS/Xcode-$2.app" ;;
        "install "*)
          [ "$INSTALL" = ok ] || { echo "Missing username or a password" >&2; exit 1; }
          mkdir -p "$APPS/Xcode-$2.app/Contents/Developer/usr/bin"
          cp "$FAKES/xcodebuild" "$APPS/Xcode-$2.app/Contents/Developer/usr/bin/" ;;
        "runtimes install") echo "$3 (27.2 - 24B118) - com.apple.CoreSimulator.SimRuntime.iOS-27-2" >> "$STATE/runtimes" ;;
      esac
      EOF
      cat > "$fakes/xcodebuild" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "xcodebuild $*" >> "$STATE/calls"
      case "$*" in
        "-license check") [ -e "$STATE/license" ] ;;
        "-license accept") [ "$ROOT" = yes ] || { echo "You have not agreed to the Xcode license agreements. Agreeing requires admin privileges" >&2; exit 69; }; touch "$STATE/license" ;;
        -checkFirstLaunchStatus) [ -e "$STATE/first-launch" ] ;;
        -runFirstLaunch) touch "$STATE/first-launch" ;;
      esac
      EOF
      cat > "$fakes/xcode-select" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "xcode-select $*" >> "$STATE/calls"
      case $1 in
        -p) cat "$STATE/selected" 2> /dev/null || { echo "unable to get active developer directory" >&2; exit 2; } ;;
        -s) [ "$ROOT" = yes ] || { echo "xcode-select: error: --switch must be run as root" >&2; exit 1; }; echo "$2" > "$STATE/selected" ;;
      esac
      EOF
      cat > "$fakes/xcrun" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "== Runtimes =="
      cat "$STATE/runtimes" 2> /dev/null
      EOF
      cat > "$fakes/as-user" <<'EOF'
      #!${pkgs.runtimeShell}
      echo "as-user $1" >> "$STATE/as-user"
      exec "$@"
      EOF
      chmod +x "$fakes"/*

      failures=0
      fail() { echo "FAIL $1"; echo "  said: $said"; sed 's/^/  call: /' "$STATE/calls" 2> /dev/null; failures=$((failures + 1)); }
      export STATE=$TMPDIR/state APPS=$TMPDIR/apps FAKES=$fakes INSTALL ROOT=yes
      fresh() { rm -rf "$STATE" "$APPS" "$TMPDIR/user"; mkdir -p "$STATE" "$APPS" "$TMPDIR/user"; }
      login() {
        mkdir -p "$TMPDIR/user/Library/Application Support/com.robotsandpencils.xcodes"
        echo '{"defaultUsername": "owner@example.invalid"}' > "$TMPDIR/user/Library/Application Support/com.robotsandpencils.xcodes/configuration.json"
      }
      run() {
        rm -f "$STATE/calls" "$STATE/as-user"
        said=$(PATH=$fakes:${pkgs.coreutils}/bin ${pkgs.bash}/bin/bash ${import ./setup.nix pkgs} \
          "$fakes/xcodes" "$fakes/as-user" alex "$TMPDIR/user" ${pin.xcode} ${pkgs.lib.escapeShellArg pin.runtime} 2>&1) && status=0 || status=$?
      }
      called() { grep -qxF -- "$1" "$STATE/calls" 2> /dev/null; }
      app=$TMPDIR/apps/Xcode-${pin.xcode}.app

      fresh; INSTALL=ok; run
      [ "$status" = 0 ] || fail "with no Apple ID login and no Xcode, setup exits 0 (exit $status)"
      case $said in *"no Apple ID login"*"xcodes install ${pin.xcode} --experimental-unxip --empty-trash"*) ;; *) fail "with no Apple ID login and no Xcode, setup prints the login and install step" ;; esac
      ! grep -q '^xcodes install ' "$STATE/calls" || fail "with no Apple ID login, setup never starts an install that would prompt"
      ! grep -q '^xcode-select -s' "$STATE/calls" || fail "with no Xcode, nothing is selected"
      [ ! -e "$STATE/runtimes" ] || fail "with no Xcode, no simulator runtime is installed"

      fresh; login; INSTALL=fail; run
      [ "$status" = 0 ] || fail "a failed xcodes install exits 0 (exit $status)"
      case $said in *"could not install Xcode ${pin.xcode}"*"xcodes install ${pin.xcode}"*) ;; *) fail "a failed xcodes install prints the step to run by hand" ;; esac
      ! grep -q '^xcode-select -s' "$STATE/calls" || fail "after a failed install, nothing is selected"

      fresh; login; INSTALL=ok; run
      [ "$status" = 0 ] || fail "with a login, setup exits 0 (exit $status)"
      called "xcodes install ${pin.xcode} --experimental-unxip --empty-trash --no-superuser" || fail "with a login, xcodes installs the pinned Xcode without asking for root"
      [ "$(cat "$STATE/selected" 2> /dev/null)" = "$app/Contents/Developer" ] || fail "the pinned Xcode is selected"
      [ -e "$STATE/license" ] || fail "the Xcode license is accepted"
      [ -e "$STATE/first-launch" ] || fail "Xcode's first-launch setup runs"
      called "xcodes runtimes install ${pin.runtime}" || fail "the pinned simulator runtime is installed"
      [ "$(grep -c '^xcodes ' "$STATE/calls")" = "$(grep -c '/xcodes$' "$STATE/as-user")" ] || fail "every xcodes call runs as the user, through the wrapper"

      run
      [ "$status" = 0 ] || fail "a second run exits 0 (exit $status)"
      for change in "xcodes install " "xcode-select -s" "xcodebuild -license accept" "xcodebuild -runFirstLaunch" "xcodes runtimes install"; do
        ! grep -q "^$change" "$STATE/calls" || fail "a second run with everything in place does not repeat: $change"
      done

      rm -f "$STATE/selected"; run
      [ "$(cat "$STATE/selected" 2> /dev/null)" = "$app/Contents/Developer" ] || fail "an Xcode deselected since the last run is selected again"

      fresh; login; INSTALL=ok; ROOT=no; run
      [ "$status" = 0 ] || fail "when selecting Xcode and accepting its license are refused, setup still exits 0 (exit $status)"
      case $said in *"Run: sudo xcode-select -s '$app/Contents/Developer'"*) ;; *) fail "a refused xcode-select prints the sudo step" ;; esac
      case $said in *"Run: sudo xcodebuild -license accept"*) ;; *) fail "a refused license prints the sudo step" ;; esac
      called "xcodes runtimes install ${pin.runtime}" || fail "a refused xcode-select does not stop the runtime install"
      ROOT=yes

      [ "$failures" = 0 ] || exit 1
      touch $out
    '';
  };
}
