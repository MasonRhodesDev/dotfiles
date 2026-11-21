pkgs:
pkgs.writeShellScript "xcode-setup" ''
  xcodes=$1 as_user=$2 user=$3 home=$4 version=$5 runtime=$6
  config="$home/Library/Application Support/com.robotsandpencils.xcodes/configuration.json"
  install_step="xcodes install $version --experimental-unxip --empty-trash"

  manual() {
    echo "xcode: $1. $2"
    exit 0
  }

  installed() {
    "$as_user" "$xcodes" installed "$version" 2> /dev/null | ${pkgs.coreutils}/bin/tail -n 1
  }

  app=$(installed)
  if [ -z "$app" ] || [ ! -d "$app" ]; then
    ${pkgs.jq}/bin/jq -e '(.defaultUsername // "") != ""' "$config" > /dev/null 2>&1 \
      || manual "Xcode $version is not installed, and xcodes has no Apple ID login yet" "Log in once as $user on the Mac, locally or over SSH, and run: $install_step. Then switch again to select it and add the $runtime simulator."
    "$as_user" "$xcodes" install "$version" --experimental-unxip --empty-trash --no-superuser < /dev/null \
      || manual "xcodes could not install Xcode $version" "As $user, run: $install_step. Then switch again."
    app=$(installed)
    [ -n "$app" ] && [ -d "$app" ] \
      || manual "xcodes finished, but Xcode $version is still not installed" "As $user, run: $install_step. Then switch again."
  fi

  developer=$app/Contents/Developer
  xcodebuild=$developer/usr/bin/xcodebuild
  if [ "$(xcode-select -p 2> /dev/null)" != "$developer" ]; then
    xcode-select -s "$developer" || echo "xcode: selecting $app failed. Run: sudo xcode-select -s '$developer'"
  fi
  if ! "$xcodebuild" -license check > /dev/null 2>&1; then
    "$xcodebuild" -license accept || echo "xcode: accepting the Xcode license failed. Run: sudo xcodebuild -license accept"
  fi
  if ! "$xcodebuild" -checkFirstLaunchStatus > /dev/null 2>&1; then
    "$xcodebuild" -runFirstLaunch || echo "xcode: Xcode's first-launch setup failed. Run: sudo xcodebuild -runFirstLaunch"
  fi
  if ! "$as_user" xcrun simctl list runtimes 2> /dev/null | ${pkgs.gnugrep}/bin/grep -qF -- "$runtime ("; then
    "$as_user" "$xcodes" runtimes install "$runtime" < /dev/null \
      || echo "xcode: installing the $runtime simulator failed. As $user, run: xcodes runtimes install '$runtime'"
  fi
  exit 0
''
