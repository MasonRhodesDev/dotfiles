{ pkgs }:
let
  homeFiles = pkgs.runCommand "home-manager-files" { } ''
    mkdir -p $out/.bashrc.d $out/.config/systemd/user/default.target.wants $out/.local/share/dotfiles
    echo "new bashrc" > $out/.bashrc
    echo "new drop-in" > $out/.bashrc.d/herdr.bashrc
    echo "new unit" > $out/.config/systemd/user/herdr.service
    ln -s ../herdr.service $out/.config/systemd/user/default.target.wants/herdr.service
    echo ".claude/settings.json" > $out/.local/share/dotfiles/mutable-paths
    printf '#!${pkgs.runtimeShell}\necho "  ~/.claude/settings.json: removes from hooks.Stop: {\\"in\\":\\"$HOME\\"}"\n' > $out/.local/share/dotfiles/mutable-plan
    chmod +x $out/.local/share/dotfiles/mutable-plan
    printf '#!${pkgs.runtimeShell}\necho "fpkg (foreign) cannot load libgone.so.3: /opt/f/libuser.so need it. Rebuild fpkg."\n' > $out/.local/share/dotfiles/unresolved-libraries
    chmod +x $out/.local/share/dotfiles/unresolved-libraries
  '';

  sdSwitch = pkgs.writeShellScriptBin "sd-switch" ''
    echo "sd-switch $*"
  '';

  activate = pkgs.writeShellScript "activate" ''
    set -eu
    sd_switch=${sdSwitch}/bin/sd-switch
    generation=$(dirname "$0")
    files=$(readlink -e "$generation/home-files")
    current=$HOME/.local/state/home-manager/gcroots/current-home
    old=
    if [ -e "$current" ]; then old=$(readlink -e "$current"); fi

    mkdir -p "$HOME/.local/state/nix/profiles"
    if [ "$USER" != alex ]; then echo "Error: USER is set to \"$USER\" but we expect \"alex\""; exit 1; fi
    if [ -e "$FAKE/terminated-while-activating" ]; then kill -TERM "$PPID"; exit 0; fi
    killed=$(cat "$FAKE/killed" 2>/dev/null || true)
    if [ "$killed" = before-linking ]; then kill -KILL "$PPID"; exit 0; fi
    cd "$files"
    find . \( -type f -o -type l \) | while IFS= read -r leaf; do
      target=$HOME/''${leaf#./}
      if [ -e "$target" ] && [[ $(readlink "$target") != /nix/store/*-home-manager-files/* ]]; then
        if cmp -s "$leaf" "$target"; then continue; fi
        if [ ! -L "$target" ] && [ ! -e "$target.$HOME_MANAGER_BACKUP_EXT" ]; then continue; fi
        echo "Existing file '$target' would be clobbered"
        exit 1
      fi
    done

    if [ "$old" != "$(readlink -e "$generation")" ]; then
      nix-env --profile "$HOME/.local/state/nix/profiles/home-manager" --set "$generation"
    fi
    find . \( -type f -o -type l \) | while IFS= read -r leaf; do
      target=$HOME/''${leaf#./}
      if [ -e "$target" ] && [ ! -L "$target" ]; then mv "$target" "$target.$HOME_MANAGER_BACKUP_EXT"; fi
      mkdir -p "$(dirname "$target")"
      ln -Tsf "$files/''${leaf#./}" "$target"
    done
    if [ "$killed" = after-linking ]; then kill -KILL "$PPID"; exit 0; fi
    if [ -e "$FAKE/a-file-replaces-the-link" ]; then rm "$HOME/.bashrc"; echo "written late" > "$HOME/.bashrc"; fi
    if [ -e "$FAKE/a-later-step-fails" ]; then echo "Error: a step after linking failed"; exit 1; fi

    if [ -z "$old" ]; then echo $(( $(cat "$FAKE/unit.pid") + 1 )) > "$FAKE/unit.pid"; fi
    nix-store --realise "$generation" --add-root "$current" > /dev/null
    echo ACTIVATED
    touch "$FAKE/activated"
  '';
in
pkgs.runCommand "check-dot-switch" { } ''
  export HOME=$TMPDIR/home USER=alex FAKE=$TMPDIR/fake DOTFILES_FLAKE=$TMPDIR/fake/flake
  generation=$FAKE/generation
  state=$HOME/.local/state/dotfiles
  aside=$state/set-aside
  current=$HOME/.local/state/home-manager/gcroots/current-home
  mkdir -p $FAKE/bin $FAKE/tools $DOTFILES_FLAKE $generation/home-path/bin $FAKE/generation-before
  touch $DOTFILES_FLAKE/flake.nix
  ln -s ${homeFiles} $generation/home-files
  ln -s ${homeFiles} $FAKE/generation-before/home-files
  ln -s ${activate} $generation/activate

  cat > $FAKE/bin/nix <<'EOF'
  #!/bin/sh
  case "$*" in
    *"#lib.machines --raw"*) printf box ;;
    *"#lib.machines.box.system --raw"*) printf x86_64-linux ;;
    *"#lib.machines.box.user --raw"*) printf 'alex\n%s' "$HOME" ;;
    *builtins.currentSystem*) printf x86_64-linux ;;
    build*"#lib.machines.box.build"*) echo "$FAKE/generation" ;;
    *) echo "nix stub: unexpected arguments: $*" >&2; exit 2 ;;
  esac
  EOF
  cat > $FAKE/bin/sudo <<'EOF'
  #!/bin/sh
  exec "$@"
  EOF
  cat > $FAKE/bin/nix-store <<'EOF'
  #!/bin/sh
  [ "$1" = --realise ] && [ "$3" = --add-root ] || { echo "nix-store stub: unexpected arguments: $*" >&2; exit 2; }
  mkdir -p "$(dirname "$4")" && ln -sfn "$2" "$4" && echo "$4"
  EOF
  cat > $FAKE/bin/nix-env <<'EOF'
  #!/bin/sh
  [ "$1" = --profile ] && [ "$3" = --set ] || { echo "nix-env stub: unexpected arguments: $*" >&2; exit 2; }
  mkdir -p "$(dirname "$2")" && ln -sfn "$4" "$2"
  EOF
  cat > $FAKE/bin/systemctl <<'EOF'
  #!/bin/sh
  case "$*" in
    "--user is-system-running") echo running ;;
    "--user is-active --quiet "*) [ -e "$FAKE/active/$4" ] ;;
    "--user stop "*)
      if [ -e "$HOME/.config/systemd/user/$3" ]; then echo "$3" >> "$FAKE/stopped-with-file"; fi
      rm -f "$FAKE/active/$3" ;;
    "--user start "*) touch "$FAKE/active/$3" ;;
    "--user daemon-reload") ;;
    *) exit 1 ;;
  esac
  EOF
  cat > $FAKE/tools/chezmoi <<'EOF'
  #!/bin/sh
  [ "$1" = managed ] && printf '%s\n' "$HOME/.bashrc" "$HOME/.old-thing" "$HOME/.claude/settings.json" "$HOME/.config/systemd/user/old.timer"
  EOF
  cat > $FAKE/bin/pacman <<'EOF'
  #!/bin/sh
  [ "$1 $2" = "-Qo --" ] || { echo "pacman stub: unexpected arguments: $*" >&2; exit 2; }
  case "$3" in
    */usr/bin/atuin) echo "$3 is owned by atuin 18.24.6-1" ;;
    */usr/bin/git | */usr/bin/git-shell) echo "$3 is owned by git 1:2.56.0-1" ;;
    */usr/bin/btop) echo "$3 is owned by btop 1.4.7-1" ;;
    */usr/bin/fnm) echo "$3 is owned by fnm 1.39.0-1" ;;
    */usr/bin/cargo) echo "$3 is owned by rust 1:1.99.1-2" ;;
    */usr/bin/magick | */usr/bin/convert) echo "$3 is owned by imagemagick 7.1.2.35-1" ;;
    */usr/bin/java) echo "$3 is owned by java-runtime-common 3-5" ;;
    */java-27-openjdk/bin/java) echo "$3 is owned by jdk-openjdk 27.0.1.u8-1" ;;
    *) echo "error: No package owns $3" >&2; exit 1 ;;
  esac
  EOF
  export DOTFILES_DISTRO_BIN=$FAKE/usr/bin
  mkdir -p $DOTFILES_DISTRO_BIN $FAKE/usr/lib/jvm/java-27-openjdk/bin
  touch $FAKE/usr/lib/jvm/java-27-openjdk/bin/java
  ln -s ../lib/jvm/java-27-openjdk/bin/java $DOTFILES_DISTRO_BIN/java
  in_profile() {
    mkdir -p "$FAKE/nix/store/0123456789abcdefghijklmnopqrstuv-$1/bin"
    touch "$FAKE/nix/store/0123456789abcdefghijklmnopqrstuv-$1/bin/$2"
    ln -s "$FAKE/nix/store/0123456789abcdefghijklmnopqrstuv-$1/bin/$2" $generation/home-path/bin/$2
    [ "''${3:-}" = only ] || touch $DOTFILES_DISTRO_BIN/$2
  }
  in_profile atuin-18.15.2 atuin
  in_profile git-2.54.0 git
  in_profile git-2.54.0 git-shell
  in_profile btop-1.4.8 btop
  in_profile fnm-1.39.0 fnm
  in_profile imagemagick-7.1.2-34 magick
  in_profile imagemagick-7.1.2-35 convert
  in_profile openjdk-21.0.12.1+1 java only
  in_profile fd-10.4.2 fd only
  in_profile rustup-1.29.3 rustup only
  ln -s "$FAKE/nix/store/0123456789abcdefghijklmnopqrstuv-rustup-1.29.3/bin/rustup" $generation/home-path/bin/cargo
  touch $DOTFILES_DISTRO_BIN/cargo
  chmod +x $FAKE/bin/* $FAKE/tools/*
  export PATH=$FAKE/bin:$PATH

  root_program() {
    { echo '#!/bin/sh'; cat; } > $generation/home-path/bin/dotfiles-root-apply
    chmod +x $generation/home-path/bin/dotfiles-root-apply
    rm -f $FAKE/activated
  }
  switch() { bash ${../dot} --private stub --machine box switch 2>&1; }
  plan() { bash ${../dot} --private stub --machine box plan 2>&1; }
  fail() { echo "FAIL $1"; echo "$2"; exit 1; }
  section() { sed -n "/^$1/,/^\$/p" <<< "$result"; }

  new_home() {
    chmod -R u+w "$HOME" 2>/dev/null || true
    rm -rf "$HOME" $FAKE/activated $FAKE/a-later-step-fails $FAKE/a-file-replaces-the-link $FAKE/terminated-while-activating $FAKE/killed $FAKE/bin/chezmoi $FAKE/active $FAKE/stopped-with-file
    mkdir -p "$HOME" $FAKE/active
    echo 100 > $FAKE/unit.pid
  }
  in_the_way() {
    mkdir -p "$HOME/.bashrc.d" "$HOME/.config/systemd/user/default.target.wants"
    echo "old drop-in" > "$HOME/.bashrc.d/herdr.bashrc"
    echo "the owner's own" > "$HOME/.bashrc.d/local.bashrc"
    echo "old unit" > "$HOME/.config/systemd/user/herdr.service"
    ln -s "$HOME/.config/systemd/user/herdr.service" "$HOME/.config/systemd/user/default.target.wants/herdr.service"
  }
  chezmoi_wrote() {
    ln -s $FAKE/tools/chezmoi $FAKE/bin/chezmoi
    mkdir -p "$HOME/.claude"
    echo "chezmoi bashrc" > "$HOME/.bashrc"
    echo "left behind" > "$HOME/.old-thing"
    echo "{}" > "$HOME/.claude/settings.json"
    units=$HOME/.config/systemd/user
    mkdir -p "$units/timers.target.wants" "$units/sockets.target.requires"
    echo "chezmoi's timer" > "$units/old.timer"
    echo "the owner's timer" > "$units/own.timer"
    ln -s "$units/old.timer" "$units/timers.target.wants/old.timer"
    ln -s ../old.timer "$units/sockets.target.requires/old.timer"
    ln -s "$units/own.timer" "$units/timers.target.wants/own.timer"
  }
  contents() {
    (cd "$1" && find . ! -type d | sort | while IFS= read -r path; do
      if [ -L "$path" ]; then echo "$path -> $(readlink "$path")"; else echo "$path $(sha256sum < "$path")"; fi
    done)
  }
  snapshot() {
    contents "$HOME"
    (cd "$HOME" && find . -type d | sort) | grep -vxF -e ./.local -e ./.local/state -e ./.local/state/nix -e ./.local/state/nix/profiles || true
  }
  all_linked() {
    (cd ${homeFiles} && find . \( -type f -o -type l \)) | while IFS= read -r leaf; do
      [ "$(readlink "$HOME/$leaf")" = "${homeFiles}/''${leaf#./}" ] || { echo "$leaf is not the generation's link"; exit 1; }
    done
  }

  new_home
  root_program <<'EOF'
  echo "installed /etc/net.conf"
  echo "dotfiles-root-apply: enable missing.service failed, continuing" >&2
  echo "dotfiles-root-apply: failed: enable missing.service. Not recorded, so the next switch runs it again." >&2
  exit 1
  EOF
  if result=$(switch); then fail "a failed root program makes dot exit non-zero" "$result"; fi
  [ -e $FAKE/activated ] || fail "a failed root program does not block home activation" "$result"
  grep -qF "installed /etc/net.conf" <<< "$result" || fail "the root program's output is shown" "$result"
  case ''${result##*ACTIVATED} in
    *"dot: ROOT STEPS FAILED"*"enable missing.service"*) ;;
    *) fail "after activating, dot names the failed root steps" "$result" ;;
  esac

  root_program <<'EOF'
  echo "installed /etc/net.conf"
  EOF
  result=$(switch) || fail "a clean root program makes dot exit 0" "$result"
  [ -e $FAKE/activated ] || fail "a clean root program is followed by home activation" "$result"
  case $result in *"ROOT STEPS FAILED"*) fail "a clean switch reports no failure" "$result" ;; esac

  new_home
  result=$(switch) || fail "a first switch goes through" "$result"
  grep -qxF "dot: warning: fpkg (foreign) cannot load libgone.so.3: /opt/f/libuser.so need it. Rebuild fpkg." <<< "$result" \
    || fail "a switch warns about a foreign package that cannot load a library, and goes through" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "a first switch leaves a running unit's process alone" "$result"
  problem=$(all_linked) || fail "a first switch links every home file: $problem" "$result"
  [ "$(readlink -e "$HOME/.local/state/nix/profiles/home-manager")" = "$(readlink -e $generation)" ] \
    || fail "a first switch records the generation in the home-manager profile" "$result"
  result=$(switch) || fail "a second switch goes through" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "a second switch leaves a running unit's process alone" "$result"
  [ -z "$(find "$state" ! -type d 2>/dev/null)" ] || fail "a switch that went through leaves no record behind" "$(contents "$state")"

  new_home
  in_the_way
  result=$(switch) || fail "a home with a live link and regular files in the way still activates" "$result"
  problem=$(all_linked) || fail "what was in the way is replaced by the generation's link: $problem" "$result"
  [ "$(ls -A "$HOME/.bashrc.d" | tr '\n' ' ')" = "herdr.bashrc local.bashrc " ] \
    || fail "nothing is set aside into a directory that programs read whole" "$(ls -A "$HOME/.bashrc.d")"
  [ "$(ls -A "$HOME/.config/systemd/user/default.target.wants")" = herdr.service ] \
    || fail "nothing is set aside into a unit's wants directory" "$(ls -A "$HOME/.config/systemd/user/default.target.wants")"
  [ "$(cat "$aside/.bashrc.d/herdr.bashrc")" = "old drop-in" ] || fail "a regular file in the way is kept" "$(contents "$state")"
  [ "$(cat "$aside/.config/systemd/user/herdr.service")" = "old unit" ] || fail "a unit file in the way is kept" "$(contents "$state")"
  [ "$(readlink "$aside/.config/systemd/user/default.target.wants/herdr.service")" = "$HOME/.config/systemd/user/herdr.service" ] \
    || fail "a live link in the way is kept as the link it was" "$(contents "$state")"
  [ "$(cat "$HOME/.bashrc.d/local.bashrc")" = "the owner's own" ] || fail "a file the generation does not have stays" "$result"
  grep -qF "$aside" <<< "$result" || fail "dot says where it put what was in the way" "$result"

  new_home
  in_the_way
  chezmoi_wrote
  before=$(snapshot)
  if result=$(USER=mallory switch); then fail "an activation that aborts makes dot exit non-zero" "$result"; fi
  [ "$(snapshot)" = "$before" ] || fail "an activation that aborts leaves the home as it was, with no directory it did not have" "$(diff <(echo "$before") <(snapshot))"
  grep -q "dot: .*put back" <<< "$result" || fail "dot says it put the files back" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "an aborted switch leaves a running unit's process alone" "$result"

  result=$(switch) || fail "the switch after an aborted one goes through" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "the switch after an aborted first one is still a first switch" "$result"
  problem=$(all_linked) || fail "the switch after an aborted one links every home file: $problem" "$result"
  [ "$(cat "$state/chezmoi-retired/.bashrc")" = "chezmoi bashrc" ] || fail "a file chezmoi wrote is retired" "$(contents "$state")"
  [ "$(cat "$state/chezmoi-retired/.old-thing")" = "left behind" ] || fail "a file chezmoi wrote that the flake lacks is retired" "$(contents "$state")"
  [ ! -e "$HOME/.old-thing" ] || fail "a retired file is gone from the home" "$result"
  [ "$(cat "$HOME/.claude/settings.json")" = "{}" ] || fail "a file the app owns is not retired" "$result"
  [ "$(cat "$aside/.bashrc.d/herdr.bashrc")" = "old drop-in" ] || fail "a file chezmoi did not write is set aside" "$(contents "$state")"
  units=.config/systemd/user
  [ "$(cat "$state/chezmoi-retired/$units/old.timer")" = "chezmoi's timer" ] || fail "a unit file chezmoi wrote is retired" "$(contents "$state")"
  [ "$(readlink "$state/chezmoi-retired/$units/timers.target.wants/old.timer")" = "$HOME/$units/old.timer" ] \
    && [ "$(readlink "$state/chezmoi-retired/$units/sockets.target.requires/old.timer")" = ../old.timer ] \
    || fail "the links that enable a retired unit file are retired with it, as the links they were" "$(contents "$state")"
  [ -z "$(find "$HOME/$units" -xtype l)" ] || fail "retiring a unit file leaves no dangling link" "$(find "$HOME/$units" -xtype l)"
  [ "$(readlink "$HOME/$units/timers.target.wants/own.timer")" = "$HOME/$units/own.timer" ] || fail "a link that enables a unit chezmoi did not write stays" "$result"

  new_home
  in_the_way
  chezmoi_wrote
  before=$(snapshot)
  touch $FAKE/a-later-step-fails
  if result=$(switch); then fail "a late failure makes dot exit non-zero" "$result"; fi
  [ "$(snapshot)" = "$before" ] || fail "a late failure leaves the home as it was" "$(diff <(echo "$before") <(snapshot))"
  grep -qF "dot: put back $HOME/.bashrc.d/herdr.bashrc" <<< "$result" || fail "dot says it put back a file whose place a link had taken" "$result"
  rm $FAKE/a-later-step-fails
  result=$(switch) || fail "the switch after a late failure goes through" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "the switch after a late failure of a first one is still a first switch" "$result"
  [ "$(cat "$state/chezmoi-retired/.bashrc")" = "chezmoi bashrc" ] && [ "$(cat "$aside/.bashrc.d/herdr.bashrc")" = "old drop-in" ] \
    || fail "the switch after a late failure keeps what was there before the first one" "$(contents "$state")"

  new_home
  mkdir -p "$HOME/.config/systemd"
  echo "not a directory" > "$HOME/.config/systemd/user"
  before=$(snapshot)
  touch $FAKE/a-later-step-fails
  if result=$(switch); then fail "a late failure over a file where a directory must go makes dot exit non-zero" "$result"; fi
  [ "$(snapshot)" = "$before" ] || fail "a late failure puts back a file that a directory of links replaced" "$(diff <(echo "$before") <(snapshot))"

  new_home
  chezmoi_wrote
  touch $FAKE/a-later-step-fails $FAKE/a-file-replaces-the-link
  if result=$(switch); then fail "a late failure that left a file makes dot exit non-zero" "$result"; fi
  [ "$(cat "$HOME/.bashrc")" = "written late" ] || fail "a file something else put where a moved one was is left alone" "$result"
  [ "$(cat "$state/chezmoi-retired/.bashrc")" = "chezmoi bashrc" ] || fail "what could not be put back stays where it was moved to" "$(contents "$state")"
  [ "$(cat "$HOME/.old-thing")" = "left behind" ] || fail "the rest is put back" "$result"
  grep -qF "$HOME/.bashrc " <<< "$result" && grep -qF "mv -T $state/chezmoi-retired/.bashrc $HOME/.bashrc" <<< "$result" \
    || fail "dot names what it could not put back, and the command that does" "$result"

  new_home
  in_the_way
  before=$(snapshot)
  touch $FAKE/terminated-while-activating
  if result=$(switch); then fail "an interrupted switch exits non-zero" "$result"; fi
  [ "$(snapshot)" = "$before" ] || fail "an interrupted switch leaves the home as it was" "$(diff <(echo "$before") <(snapshot))"

  new_home
  in_the_way
  chezmoi_wrote
  switch > /dev/null || fail "a first switch in a home chezmoi wrote goes through" ""
  first=$(contents "$HOME")
  for moment in before-linking after-linking; do
    new_home
    in_the_way
    chezmoi_wrote
    before=$(snapshot)
    echo $moment > $FAKE/killed
    if result=$(switch); then fail "a switch killed $moment exits non-zero" "$result"; fi
    rm $FAKE/killed
    [ "$(cat "$state/chezmoi-retired/.bashrc" 2>&1)" = "chezmoi bashrc" ] || fail "the check kills a switch $moment, after it moved files" "$(contents "$state")"
    result=$(plan) || fail "plan exits 0 after a switch killed $moment, which can be undone" "$result"
    section "Unfinished switch" | grep -qx "  ~/.bashrc" && section "Unfinished switch" | grep -qx "  ~/.bashrc.d/herdr.bashrc" \
      || fail "plan lists what the switch after one killed $moment puts back first" "$result"
    result=$(switch) || fail "the switch after one killed $moment goes through" "$result"
    grep -qF "dot: an earlier switch did not finish" <<< "$result" || fail "the switch after one killed $moment says it undoes that one first" "$result"
    [ "$(contents "$HOME")" = "$first" ] || fail "the switch after one killed $moment leaves what a first switch leaves" "$(diff <(echo "$first") <(contents "$HOME"))"
    [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "the switch after one killed $moment is still a first switch" "$result"
  done

  new_home
  chezmoi_wrote
  echo after-linking > $FAKE/killed
  if result=$(switch); then fail "a killed switch exits non-zero" "$result"; fi
  rm $FAKE/killed
  echo "the owner's new file" > "$HOME/.old-thing"
  rm $FAKE/bin/chezmoi
  if result=$(plan); then fail "plan exits 1 when a killed switch cannot be undone" "$result"; fi
  section "Unfinished switch" | grep -F "~/.old-thing" | grep -qF "$state/chezmoi-retired/.old-thing" || fail "plan names what cannot be put back and where it is" "$result"
  rm -f $FAKE/activated
  if result=$(switch); then fail "a switch refuses while a killed one cannot be undone" "$result"; fi
  [ ! -e $FAKE/activated ] || fail "a switch that refuses does not activate" "$result"
  [ "$(cat "$HOME/.old-thing")" = "the owner's new file" ] && [ "$(cat "$state/chezmoi-retired/.old-thing")" = "left behind" ] \
    || fail "a switch that refuses leaves both files where they are" "$(contents "$HOME")"
  grep -qF "mv -T $state/chezmoi-retired/.old-thing $HOME/.old-thing" <<< "$result" || fail "a switch that refuses gives the command that puts the file back" "$result"
  if result=$(switch); then fail "a switch still refuses while nothing was settled" "$result"; fi
  rm "$HOME/.old-thing"
  mv -T "$state/chezmoi-retired/.old-thing" "$HOME/.old-thing"
  result=$(switch) || fail "a switch goes through once the owner ran the command" "$result"
  [ "$(cat "$HOME/.old-thing")" = "left behind" ] || fail "the file the owner put back is where it was" "$(contents "$HOME")"

  new_home
  in_the_way
  mkdir -p "$aside/.bashrc.d" "$state/chezmoi-retired" "$(dirname "$current")" "$HOME/.local/share/dotfiles"
  before=$(snapshot)
  touch $FAKE/a-later-step-fails
  if result=$(switch); then fail "a late failure in a home with empty directories makes dot exit non-zero" "$result"; fi
  [ "$(snapshot)" = "$before" ] || fail "a failed switch leaves an empty directory that was there before it" "$(diff <(echo "$before") <(snapshot))"

  new_home
  in_the_way
  mkdir -p "$aside/.bashrc.d"
  echo "set aside earlier" > "$aside/.bashrc.d/herdr.bashrc"
  before=$(contents "$HOME")
  if result=$(switch); then fail "a target dot cannot set aside makes the switch exit non-zero" "$result"; fi
  [ "$(contents "$HOME")" = "$before" ] || fail "a switch that cannot set a target aside moves nothing" "$(contents "$HOME")"
  [ ! -e $FAKE/activated ] || fail "a switch that cannot set a target aside does not activate" "$result"
  grep -qF ".bashrc.d/herdr.bashrc" <<< "$result" || fail "the switch names the target it cannot set aside" "$result"
  if result=$(plan); then fail "plan exits 1 when a target would still collide" "$result"; fi
  sed -n '/^Still in the way/,/^$/p' <<< "$result" | grep -qF ".bashrc.d/herdr.bashrc" || fail "plan lists the target that would still collide" "$result"

  new_home
  chezmoi_wrote
  mkdir -p "$state/chezmoi-retired"
  echo "retired earlier" > "$state/chezmoi-retired/.old-thing"
  before=$(contents "$HOME")
  if result=$(switch); then fail "a file dot cannot retire makes the switch exit non-zero" "$result"; fi
  [ "$(contents "$HOME")" = "$before" ] || fail "a switch that cannot retire a file moves nothing, and keeps the earlier copy" "$(contents "$HOME")"
  [ ! -e $FAKE/activated ] || fail "a switch that cannot retire a file does not activate" "$result"
  grep -qF "$state/chezmoi-retired/.old-thing" <<< "$result" || fail "the switch names the earlier copy that is in the way" "$result"
  if result=$(plan); then fail "plan exits 1 when a file cannot be retired" "$result"; fi
  section "Still in the way" | grep -qF "~/.old-thing" || fail "plan lists the file that cannot be retired" "$result"
  if section "Retired" | grep -qF ".old-thing"; then fail "plan lists a file that cannot be retired once" "$result"; fi

  for kind in file link; do
    new_home
    mkdir -p "$HOME/.config/systemd"
    echo "not a directory" > "$HOME/.config/systemd/user"
    if [ $kind = link ]; then
      mv "$HOME/.config/systemd/user" "$HOME/.config/systemd/elsewhere"
      ln -s elsewhere "$HOME/.config/systemd/user"
    fi
    result=$(plan) || fail "plan exits 0 with a $kind where a directory must go" "$result"
    section "Set aside" | grep -qx "  ~/.config/systemd/user" || fail "plan lists a $kind where a directory must go" "$result"
    result=$(switch) || fail "a home with a $kind where a directory must go still activates" "$result"
    problem=$(all_linked) || fail "a $kind where a directory must go is replaced by the directory of links: $problem" "$result"
    case $kind in
      file) [ "$(cat "$aside/.config/systemd/user")" = "not a directory" ] ;;
      link) [ "$(readlink "$aside/.config/systemd/user")" = elsewhere ] ;;
    esac || fail "a $kind where a directory must go is kept as it was" "$(contents "$state")"
  done

  new_home
  in_the_way
  chezmoi_wrote
  root_program <<'EOF'
  echo "a root program that never ran"
  EOF
  before=$(contents "$HOME"; find "$HOME" | sort)
  result=$(plan) || fail "plan exits 0 when the switch would go through" "$result"
  [ "$(contents "$HOME"; find "$HOME" | sort)" = "$before" ] || fail "plan changes nothing in the home" "$(find "$HOME" | sort)"
  [ ! -e $FAKE/activated ] || fail "plan does not activate" "$result"
  [ "$(cat $FAKE/unit.pid)" = 100 ] || fail "plan leaves units alone" "$result"
  section "Retired" | grep -qx "  ~/.bashrc" || fail "plan lists a file chezmoi wrote as retired" "$result"
  section "Retired" | grep -qx "  ~/.old-thing" || fail "plan lists a file only chezmoi has as retired" "$result"
  if section "Retired" | grep -qF "settings.json"; then fail "plan does not retire a file the app owns" "$result"; fi
  for path in old.timer timers.target.wants/old.timer sockets.target.requires/old.timer; do
    section "Retired" | grep -qx "  ~/.config/systemd/user/$path" || fail "plan lists a retired unit file and the links that enable it: $path" "$result"
  done
  if section "Retired" | grep -qF "own.timer"; then fail "plan does not retire the link to a unit chezmoi did not write" "$result"; fi
  section "Set aside" | grep -qx "  ~/.bashrc.d/herdr.bashrc" || fail "plan lists a regular file in the way" "$result"
  section "Set aside" | grep -qx "  ~/.config/systemd/user/default.target.wants/herdr.service" || fail "plan lists a live link in the way" "$result"
  if section "Set aside" | grep -qx "  ~/.bashrc"; then fail "plan lists a path once, under what moves it" "$result"; fi
  units=$generation/home-files/.config/systemd/user
  section "User units" | grep -qF "sd-switch --dry-run --old-units $units --new-units $units" \
    || fail "before a first switch, plan asks sd-switch with the new units as the old ones" "$result"
  section "Root program" | grep -qF "runs it" || fail "plan says the root program would run" "$result"
  section "Libraries that foreign packages cannot load" | grep -qxF "  fpkg (foreign) cannot load libgone.so.3: /opt/f/libuser.so need it. Rebuild fpkg." \
    || fail "plan lists a foreign package that cannot load a library, as a warning that does not stop the switch" "$result"
  [ "$(section "Nix copies older")" = "$(printf '%s\n' "Nix copies older than the distro copy they shadow" \
      "  atuin: Nix 18.15.2, pacman atuin 18.24.6" \
      "  git: Nix 2.54.0, pacman git 2.56.0" \
      "  java: Nix 21.0.12.1+1, pacman jdk-openjdk 27.0.1.u8" \
      "  magick: Nix 7.1.2-34, pacman imagemagick 7.1.2.35" "")" ] \
    || fail "plan names each Nix copy older than the distro package it shadows, once per package, through links, and not one that is equal, equal but for its separators, newer, a proxy for another command, or has no distro copy" "$result"
  section "Files written at activation" | grep -qxF "  ~/.claude/settings.json: removes from hooks.Stop: {\"in\":\"$HOME\"}" \
    || fail "plan lists what activation would change in the files it writes, read from this home" "$result"

  if result=$(USER=mallory plan); then fail "plan exits 1 when the entry is for another user" "$result"; fi
  section "User" | grep -qF "mallory" || fail "plan names the user the entry does not match" "$result"

  new_home
  mkdir -p "$(dirname "$current")"
  ln -s $FAKE/generation-before "$current"
  result=$(plan) || fail "plan exits 0 on a machine that has switched before" "$result"
  section "User units" | grep -qF "sd-switch --dry-run --old-units $FAKE/generation-before/home-files/.config/systemd/user --new-units $units" \
    || fail "after a first switch, plan asks sd-switch with the current generation's units as the old ones" "$result"
  [ "$(readlink "$current")" = $FAKE/generation-before ] || fail "plan leaves the current generation alone" "$result"
  if section "Set aside" | grep -q "~/"; then fail "plan lists nothing to set aside in a clean home" "$result"; fi

  new_home
  echo "box: secrets = \"infisical\", and its private entry sets no private.infisical.projectId" > $generation/dotfiles-warnings
  result=$(plan) || fail "plan exits 0 with a warning" "$result"
  section "Warnings" | grep -qx '  box: secrets = "infisical", and its private entry sets no private.infisical.projectId' || fail "plan shows the generation's warning" "$result"
  result=$(switch) || fail "a switch with a warning goes through" "$result"
  grep -qx 'dot: warning: box: secrets = "infisical", and its private entry sets no private.infisical.projectId' <<< "$result" || fail "switch shows the generation's warning" "$result"
  rm $generation/dotfiles-warnings
  result=$(plan) || fail "plan exits 0 without a warning" "$result"
  section "Warnings" | grep -qx "  none" || fail "plan says when there is no warning" "$result"

  new_home
  in_the_way
  chezmoi_wrote
  userunits=.config/systemd/user
  mkdir -p "$HOME/$userunits/timers.target.wants"
  ln -s ../herdr.service "$HOME/$userunits/timers.target.wants/herdr.service"
  touch $FAKE/active/old.timer $FAKE/active/herdr.service $FAKE/active/own.timer
  result=$(plan) || fail "plan exits 0 with units running from files that move" "$result"
  section "Stopped before" | grep -qx "  old.timer" || fail "plan lists a running unit whose file is retired" "$result"
  section "Stopped before" | grep -qx "  herdr.service  (started again from the generation's unit)" \
    || fail "plan lists a running unit whose file is set aside, which the generation's unit replaces" "$result"
  if section "Stopped before" | grep -qF own.timer; then fail "plan does not list a unit whose file stays" "$result"; fi
  section "Set aside" | grep -qx "  ~/$userunits/timers.target.wants/herdr.service" || fail "plan sets aside a link that enables a set-aside unit file" "$result"
  [ -e $FAKE/active/old.timer ] && [ ! -e $FAKE/stopped-with-file ] || fail "plan stops nothing" "$result"
  result=$(switch) || fail "a switch with units running from files that move goes through" "$result"
  [ ! -e $FAKE/active/old.timer ] || fail "a running unit whose file is retired is stopped" "$result"
  grep -qx old.timer $FAKE/stopped-with-file && grep -qx herdr.service $FAKE/stopped-with-file \
    || fail "a unit is stopped while its file is still in place" "$(cat $FAKE/stopped-with-file 2>&1)"
  [ -e $FAKE/active/herdr.service ] || fail "a unit the generation enables runs again, from the generation's unit" "$result"
  [ -e $FAKE/active/own.timer ] || fail "a unit whose file stays keeps running" "$result"
  [ ! -e "$HOME/$userunits/timers.target.wants/herdr.service" ] && [ "$(readlink "$aside/$userunits/timers.target.wants/herdr.service")" = ../herdr.service ] \
    || fail "a link that enables a set-aside unit file, and that the generation lacks, is set aside as the link it was" "$(contents "$state")"
  [ ! -e "$state/stopped" ] || fail "a switch that went through keeps no record of stopped units" "$(contents "$state")"

  new_home
  in_the_way
  chezmoi_wrote
  touch $FAKE/active/old.timer $FAKE/active/herdr.service $FAKE/a-later-step-fails
  before=$(snapshot)
  if result=$(switch); then fail "a late failure with units running from files that move exits non-zero" "$result"; fi
  grep -qx old.timer $FAKE/stopped-with-file || fail "the failed switch stopped the unit first" "$result"
  [ -e $FAKE/active/old.timer ] && [ -e $FAKE/active/herdr.service ] || fail "a switch that did not go through starts again the units it stopped" "$result"
  [ "$(snapshot)" = "$before" ] || fail "a late failure with stopped units leaves the home as it was" "$(diff <(echo "$before") <(snapshot))"

  new_home
  root_program <<'EOF'
  if [ "$1" = --retiring ]; then echo old-root.service; exit 0; fi
  echo "applied"
  EOF
  result=$(plan) || fail "plan exits 0 when the root program would disable a unit" "$result"
  section "Root program" | grep -qx "    old-root.service" || fail "plan lists the units the root program would disable and stop" "$result"

  mkdir -p $FAKE/remote $FAKE/source/nix
  cat > $FAKE/remote/nix <<'EOF'
  #!/bin/sh
  echo "$*" >> "$FAKE/remote-calls"
  case "$*" in
    *"--override-input private git+ssh://private.example.invalid/dotfiles-private path:$FAKE/source?dir=nix#"*) ;;
    *) echo "remote nix stub: not the sent flake with the private ref: $*" >&2; exit 2 ;;
  esac
  case "$*" in build*) [ ! -e "$FAKE/remote-build-fails" ] || { echo "error: a builder failed" >&2; exit 1; } ;; esac
  case "$*" in
    *"#lib.machines --raw"*) printf box ;;
    *"#lib.machines.box.system --raw"*) if [ -e "$FAKE/darwin" ]; then printf aarch64-darwin; else printf x86_64-linux; fi ;;
    *"#lib.machines.box.user --raw"*) printf 'alex\n%s' "$HOME" ;;
    build*"#lib.machines.box.build"*) echo "$FAKE/generation" ;;
    "eval --raw "*"#lib.machines.box.build.drvPath"*) printf %s "$FAKE/box.drv" ;;
    *) echo "remote nix stub: unexpected arguments: $*" >&2; exit 2 ;;
  esac
  EOF
  printf '#!/bin/sh\n' > $FAKE/remote/nix-daemon
  cat > $FAKE/bin/ssh <<'EOF'
  #!/bin/sh
  [ "$1 $2 $3" = "-n -- builder.example.invalid" ] || { echo "ssh stub: unexpected arguments: $*" >&2; exit 255; }
  PATH=$FAKE/remote:$PATH exec bash -c "$4"
  EOF
  cat > $FAKE/bin/nix <<'EOF'
  #!/bin/sh
  echo "$*" >> "$FAKE/local-calls"
  store="ssh-ng://builder.example.invalid?remote-program=$FAKE/remote/nix-daemon"
  case "$*" in
    *--override-input* | *"$DOTFILES_FLAKE#"*) echo "nix stub: evaluated here: $*" >&2; exit 3 ;;
    *builtins.currentSystem*) if [ -e "$FAKE/darwin" ]; then printf aarch64-darwin; else printf x86_64-linux; fi ;;
    "flake prefetch --json $DOTFILES_FLAKE") printf '{"original":{"dir":"nix","type":"git"},"storePath":"%s"}\n' "$FAKE/source" ;;
    "copy --to $store $FAKE/source") echo sent >> "$FAKE/sent" ;;
    "copy --from $store "*) echo "''${*##* }" >> "$FAKE/copied" ;;
    "copy --derivation --from $store $FAKE/box.drv") echo "$FAKE/box.drv" >> "$FAKE/derivations" ;;
    "build --no-link --print-out-paths $FAKE/box.drv^*") echo "$FAKE/generation" ;;
    *) echo "nix stub: unexpected arguments: $*" >&2; exit 2 ;;
  esac
  EOF
  chmod +x $FAKE/remote/* $FAKE/bin/ssh $FAKE/bin/nix
  hosted() { bash ${../dot} --private git+ssh://private.example.invalid/dotfiles-private --machine box "$@" 2>&1; }
  local_calls() { cat $FAKE/local-calls 2>/dev/null || true; }
  fresh() { new_home; rm -f $FAKE/local-calls $FAKE/remote-calls $FAKE/copied $FAKE/derivations $FAKE/sent $FAKE/remote-build-fails $FAKE/darwin $generation/dotfiles-build-host; }

  fresh
  if result=$(hosted switch); then fail "with no build host, this stub nix refuses the private input, so the cases below can fail" "$result"; fi
  grep -qF "evaluated here" <<< "$result" || fail "with no build host, the private input is evaluated here" "$result"

  fresh
  result=$(hosted --build-host builder.example.invalid switch) || fail "a switch through a build host goes through" "$result"
  [ -e $FAKE/activated ] || fail "a switch through a build host activates the copied generation" "$result"
  ! grep -qe --override-input -e "#lib" $FAKE/local-calls || fail "nothing that names the private input is evaluated or built here" "$(local_calls)"
  grep -q "^build .*#lib.machines.box.build" $FAKE/remote-calls || fail "the generation is built on the build host" "$(cat $FAKE/remote-calls)"
  [ "$(cat $FAKE/copied)" = "$FAKE/generation" ] || fail "only the generation's closure is copied here" "$(cat $FAKE/copied 2>&1)"
  [ "$(cat $FAKE/sent)" = sent ] || fail "the public flake is sent to the build host once" "$(local_calls)"

  fresh
  result=$(hosted --build-host builder.example.invalid plan) || fail "plan through a build host goes through" "$result"
  section Generation | grep -qx "  built on builder.example.invalid, and only its closure copied here" || fail "plan says where the generation was built" "$result"
  [ ! -e $FAKE/activated ] || fail "plan through a build host activates nothing" "$result"
  ! grep -qe --override-input -e "#lib" $FAKE/local-calls || fail "plan evaluates nothing private here" "$(local_calls)"

  fresh
  echo builder.example.invalid > $generation/dotfiles-build-host
  result=$(hosted --build-host builder.example.invalid switch) || fail "a first switch through a build host goes through" "$result"
  rm -f $FAKE/copied $FAKE/local-calls
  result=$(hosted switch) || fail "the next switch finds the build host in the active generation" "$result"
  [ "$(cat $FAKE/copied)" = "$FAKE/generation" ] || fail "the build host the active generation names builds the next one" "$(local_calls)"

  fresh
  echo builder.example.invalid > $generation/dotfiles-build-host
  result=$(hosted --build-host builder.example.invalid switch) || fail "a first switch through a build host goes through" "$result"
  rm -f $FAKE/copied $FAKE/local-calls $FAKE/remote-calls $FAKE/sent
  if result=$(DOTFILES_BUILD_HOST=builder.example.invalid hosted --build-host local switch); then fail "with --build-host local, this stub nix refuses the private input here, so the switch fails" "$result"; fi
  grep -qF "evaluated here" <<< "$result" || fail "--build-host local evaluates here, over DOTFILES_BUILD_HOST and the build host the active generation names" "$result"
  [ ! -e $FAKE/remote-calls ] && [ ! -e $FAKE/sent ] && [ ! -e $FAKE/copied ] || fail "--build-host local sends nothing to a build host and copies nothing from one" "$(local_calls)"

  fresh
  touch $FAKE/darwin
  result=$(hosted --build-host builder.example.invalid build) || fail "a darwin build through a build host goes through" "$result"
  [ "$result" = "$FAKE/generation" ] || fail "a darwin build through a build host gives the generation built here" "$result"
  [ "$(cat $FAKE/derivations 2>&1)" = "$FAKE/box.drv" ] || fail "a darwin target copies the derivations the build host evaluated" "$(local_calls)"
  [ ! -e $FAKE/copied ] || fail "a darwin target copies no built output from the build host" "$(cat $FAKE/copied)"
  ! grep -q "^build" $FAKE/remote-calls || fail "the build host builds nothing for a darwin target" "$(cat $FAKE/remote-calls)"
  grep -qxF "build --no-link --print-out-paths $FAKE/box.drv^*" $FAKE/local-calls || fail "a darwin target builds the copied derivations itself" "$(local_calls)"
  ! grep -qe --override-input -e "#lib" $FAKE/local-calls || fail "a darwin target evaluates nothing private" "$(local_calls)"

  fresh
  touch $FAKE/remote-build-fails
  if result=$(hosted --build-host builder.example.invalid switch); then fail "a failed build on the build host makes dot exit non-zero" "$result"; fi
  [ ! -e $FAKE/activated ] && [ ! -e $FAKE/copied ] || fail "a failed build on the build host copies and activates nothing" "$result"
  grep -qF "the build host builder.example.invalid could not build" <<< "$result" || fail "dot says the build host could not build" "$result"
  ! grep -qe --override-input -e "#lib" $FAKE/local-calls || fail "a failed build on the build host is not retried here" "$(local_calls)"

  touch $out
''
