{ pkgs, evalHome }:
let
  home = evalHome {
    modules = [{
      dotfiles.mutable = {
        "seeded" = { strategy = "seed"; text = "from the flake\n"; };
        "copied" = { strategy = "overwrite"; text = "from the flake\n"; };
        "merged.json" = { strategy = "merge-json"; mode = "0600"; json = { managed = "flake"; nested.managed = "flake"; }; };
        "fresh.json" = { strategy = "merge-json"; json.list = [ "once" "once" ]; };
      };
    }];
  };
  activation = pkgs.writeText "activation" home.config.home.activation.dotfilesMutable.data;
  listed = json: (evalHome {
    modules = [{ dotfiles.mutable."listed.json" = { strategy = "merge-json"; inherit json; }; }];
  }).config.home.activation.dotfilesMutable.data;
  hooks = events: listed { inherit events; level = "flake"; };
  hook = command: { matcher = ""; hooks = [{ type = "command"; inherit command; }]; };
  before = pkgs.writeText "activation-before" (hooks { Start = [ (hook "ours") (hook "ours-too") ]; });
  after = pkgs.writeText "activation-after" (hooks { Start = [ (hook "ours-too") (hook "ours-new") ]; Stop = [ (hook "ours") ]; End = [ (hook "ours-end") ]; });
  later = pkgs.writeText "activation-later" (listed { events.Start = [ (hook "ours-new") (hook "ours-twice") (hook "ours-twice") ]; });
  adopting = evalHome {
    modules = [{
      dotfiles.mutable."adopted.json" = {
        strategy = "merge-json";
        json.events.Start = [ (hook "replacement") ];
        adopt.events = { Start = [ (hook "earlier") ]; End = [ (hook "earlier-end") ]; };
      };
    }];
  };
  adopt = pkgs.writeText "activation-adopt" adopting.config.home.activation.dotfilesMutable.data;
  adoptPlan = adopting.config.home.file.".local/share/dotfiles/mutable-plan".source;
  plain = home.config.home.file.".local/share/dotfiles/mutable-plan".source;
  present = evalHome {
    modules = [{
      dotfiles.mutable."app/hooks.json" = { strategy = "merge-json"; mode = "0600"; whenPresent = "app"; json.hooks = [ "ours" ]; };
    }];
  };
  presentActivation = pkgs.writeText "activation-present" present.config.home.activation.dotfilesMutable.data;
  presentPlan = present.config.home.file.".local/share/dotfiles/mutable-plan".source;
  seed = { dotfiles.mutable."mimeapps.list" = { strategy = "merge-ini"; text = "[Default Applications]\ntext/html=browser.desktop\n\n[Added Associations]\ntext/markdown=editor.desktop;\n"; }; };
  handler = { dotfiles.mutable."mimeapps.list" = { strategy = "merge-ini"; ini."Default Applications"."x-scheme-handler/magnet" = "qbt-magnet.desktop"; }; };
  ini = modules: let h = evalHome { inherit modules; }; in {
    activation = pkgs.writeText "activation-ini" h.config.home.activation.dotfilesMutable.data;
    plan = h.config.home.file.".local/share/dotfiles/mutable-plan".source;
  };
  both = ini [ seed handler ];
  seedOnly = ini [ seed ];
  handlerOnly = ini [ handler ];
in
pkgs.runCommand "check-mutable" { nativeBuildInputs = [ pkgs.jq ]; } ''
  export HOME=$TMPDIR/home
  mkdir -p "$HOME"
  errorEcho() { echo "$*" >&2; }
  activate() { ( set -euo pipefail; source ${activation} ); }
  expect() { if [ "$2" != "$3" ]; then echo "FAIL $1: got '$2', want '$3'"; exit 1; fi; }

  echo "hand written" > "$HOME/copied"
  echo '{"managed":"app","nested":{"managed":"app","own":"app"},"own":"app"}' > "$HOME/merged.json"
  activate

  expect "seed writes a missing file" "$(cat "$HOME/seeded")" "from the flake"
  expect "overwrite replaces the file" "$(cat "$HOME/copied")" "from the flake"
  expect "overwrite keeps the copy that predates the flake" "$(cat "$HOME/copied.pre-nix")" "hand written"
  expect "merge sets managed keys, keeps the app's" "$(jq -c . "$HOME/merged.json")" \
    '{"managed":"flake","nested":{"managed":"flake","own":"app"},"own":"app"}'
  expect "mode is applied" "$(stat -c %a "$HOME/merged.json")" "600"
  expect "a new file gets an element the flake declares twice once" "$(jq -c .list "$HOME/fresh.json")" '["once"]'
  expect "written files are real files" "$(find "$HOME" -type l | wc -l | tr -d ' ')" "0"

  echo "edited by the app" > "$HOME/seeded"
  echo "edited by hand again" > "$HOME/copied"
  activate
  expect "seed leaves an existing file alone" "$(cat "$HOME/seeded")" "edited by the app"
  expect "overwrite wins again" "$(cat "$HOME/copied")" "from the flake"
  expect "the first copy is kept, not replaced" "$(cat "$HOME/copied.pre-nix")" "hand written"

  hook() { jq -c -n --arg c "$1" '{matcher: "", hooks: [{type: "command", command: $c}]}'; }
  commands() { jq -c "[.events.$1[]?.hooks[].command]" "$HOME/listed.json"; }
  echo "{\"events\":{\"Start\":[$(hook theirs),$(hook ours)]},\"level\":\"app\",\"own\":1}" > "$HOME/listed.json"
  ( set -euo pipefail; source ${before} )
  expect "an array keeps the elements the flake did not write, and gains the flake's once" "$(commands Start)" '["theirs","ours","ours-too"]'
  expect "a scalar beside an array is the flake's" "$(jq -c .level "$HOME/listed.json")" '"flake"'
  ( set -euo pipefail; source ${before} )
  expect "a second switch adds nothing" "$(commands Start)" '["theirs","ours","ours-too"]'
  jq -c --arg c added-later '.events.Start += [{matcher: "", hooks: [{type: "command", command: $c}]}]' "$HOME/listed.json" > "$HOME/l" && mv "$HOME/l" "$HOME/listed.json"
  ( set -euo pipefail; source ${after} )
  expect "an element the flake wrote and no longer declares goes, and the others stay" "$(commands Start)" '["theirs","ours-too","added-later","ours-new"]'
  expect "an array the flake starts declaring is written" "$(commands Stop)" '["ours"]'
  jq -c --arg c theirs-stop '.events.Stop += [{matcher: "", hooks: [{type: "command", command: $c}]}]' "$HOME/listed.json" > "$HOME/l" && mv "$HOME/l" "$HOME/listed.json"
  ( set -euo pipefail; source ${later} )
  expect "an element the flake declares twice is written once" "$(commands Start)" '["theirs","added-later","ours-new","ours-twice"]'
  expect "an event the flake no longer declares keeps the entries it did not write" "$(commands Stop)" '["theirs-stop"]'
  expect "an event the flake no longer declares, holding only its entries, goes" "$(jq -c '.events | has("End")' "$HOME/listed.json")" false
  expect "a key the flake no longer declares goes" "$(jq -c 'has("level")' "$HOME/listed.json")" false
  expect "a key the flake never wrote stays" "$(jq -c .own "$HOME/listed.json")" 1
  settled=$(cat "$HOME/listed.json")
  ( set -euo pipefail; source ${later} )
  expect "a second switch with the same declaration changes nothing" "$(cat "$HOME/listed.json")" "$settled"
  jq -c '.events.Start += [.events.Start[2], {matcher: "", hooks: [{type: "command", command: "theirs-twice"}]}, {matcher: "", hooks: [{type: "command", command: "theirs-twice"}]}]' "$HOME/listed.json" > "$HOME/l" && mv "$HOME/l" "$HOME/listed.json"
  ( set -euo pipefail; source ${later} )
  expect "an element the flake declares that the file already holds twice is kept once, and the app's own repeats stay" "$(commands Start)" '["theirs","added-later","ours-new","ours-twice","theirs-twice","theirs-twice"]'

  adopted() { jq -c "[.events.$1[]?.hooks[].command]" "$HOME/adopted.json"; }
  echo "{\"events\":{\"Start\":[$(hook theirs),$(hook earlier)],\"End\":[$(hook earlier-end)]},\"own\":1}" > "$HOME/adopted.json"
  untouched=$(cat "$HOME/adopted.json")
  planned=$(${adoptPlan})
  expect "plan changes nothing" "$(cat "$HOME/adopted.json")" "$untouched"
  grep -qxF '  ~/adopted.json: removes from events.Start: {"matcher":"","hooks":[{"type":"command","command":"earlier"}]}' <<< "$planned" \
    || { echo "FAIL plan lists an adopted entry the flake removes"; echo "$planned"; exit 1; }
  grep -qxF '  ~/adopted.json: removes events.End: [{"matcher":"","hooks":[{"type":"command","command":"earlier-end"}]}]' <<< "$planned" \
    || { echo "FAIL plan lists an adopted event that goes with its last entry"; echo "$planned"; exit 1; }
  grep -qxF '  ~/adopted.json: adds to events.Start: {"hooks":[{"command":"replacement","type":"command"}],"matcher":""}' <<< "$planned" \
    || { echo "FAIL plan lists what the flake adds"; echo "$planned"; exit 1; }
  if grep -qF theirs <<< "$planned"; then echo "FAIL plan lists nothing for an entry the flake never owned"; echo "$planned"; exit 1; fi
  ( set -euo pipefail; source ${adopt} )
  expect "a first switch removes what an earlier manager wrote and the flake adopted, and keeps the rest" "$(adopted Start)" '["theirs","replacement"]'
  expect "an adopted event whose entries all go is removed" "$(jq -c '.events | has("End")' "$HOME/adopted.json")" false
  expect "a key nobody adopted stays" "$(jq -c .own "$HOME/adopted.json")" 1
  settled=$(cat "$HOME/adopted.json")
  expect "plan lists nothing once the file is settled" "$(${adoptPlan})" "  none"
  ( set -euo pipefail; source ${adopt} )
  expect "a second switch with adoption changes nothing" "$(cat "$HOME/adopted.json")" "$settled"
  rm "$HOME/seeded"
  echo "edited" > "$HOME/copied"
  planned=$(${plain})
  grep -qxF "  ~/seeded: written, it does not exist yet" <<< "$planned" || { echo "FAIL plan lists a seed it writes"; echo "$planned"; exit 1; }
  grep -qxF "  ~/copied: replaced by the flake's copy" <<< "$planned" || { echo "FAIL plan lists an overwrite that differs"; echo "$planned"; exit 1; }
  activate

  planned=$(${presentPlan})
  if grep -qF app/hooks.json <<< "$planned"; then echo "FAIL plan lists nothing for a file whose app is missing"; echo "$planned"; exit 1; fi
  ( set -euo pipefail; source ${presentActivation} )
  expect "a file whose app is missing is not written" "$([ -e "$HOME/app/hooks.json" ] && echo written || echo absent)" absent
  mkdir "$HOME/app"
  expect "plan lists a file once its app is there" "$(${presentPlan})" "  ~/app/hooks.json: written, it does not exist yet"
  ( set -euo pipefail; source ${presentActivation} )
  expect "a file whose app is there is written" "$(jq -c . "$HOME/app/hooks.json")" '{"hooks":["ours"]}'
  expect "with its mode" "$(stat -c %a "$HOME/app/hooks.json")" "600"

  mimeapps=$HOME/mimeapps.list
  ( set -euo pipefail; source ${handlerOnly.activation} )
  expect "keys alone write a missing file with only their section" "$(cat "$mimeapps")" "$(printf '%s\n' '[Default Applications]' x-scheme-handler/magnet=qbt-magnet.desktop)"
  mv "$mimeapps" "$TMPDIR/handler-only"
  expect "plan says a missing file is written" "$(${both.plan})" "  ~/mimeapps.list: written, it does not exist yet"
  ( set -euo pipefail; source ${both.activation} )
  expect "a missing file starts from the text, with the keys set in their section" "$(cat "$mimeapps")" \
    "$(printf '%s\n' '[Default Applications]' text/html=browser.desktop x-scheme-handler/magnet=qbt-magnet.desktop "" '[Added Associations]' 'text/markdown=editor.desktop;')"
  cat > "$mimeapps" <<'APP'
  [Default Applications]
  x-scheme-handler/magnet=transmission-gtk.desktop
  text/html=other-browser.desktop
  x-scheme-handler/irc=chat.desktop
  x-scheme-handler/mailto = mail.desktop

  [Added Associations]
  text/markdown=editor.desktop;
  x-scheme-handler/magnet=transmission-gtk.desktop;qbt-magnet.desktop;

  [Removed Associations]
  x-scheme-handler/magnet=old.desktop;
  APP
  rewritten=$(cat "$mimeapps")
  expect "plan names the one line the switch changes in a file an app rewrote" "$(${both.plan})" \
    "$(printf '%s\n' '  ~/mimeapps.list: removes the line x-scheme-handler/magnet=transmission-gtk.desktop' '  ~/mimeapps.list: adds the line x-scheme-handler/magnet=qbt-magnet.desktop')"
  expect "plan changes nothing" "$(cat "$mimeapps")" "$rewritten"
  ( set -euo pipefail; source ${both.activation} )
  expect "the switch puts the magnet default back in place and leaves every other line of the rewritten file as the app left it" \
    "$(cat "$mimeapps")" "$(sed 's/^x-scheme-handler\/magnet=transmission-gtk.desktop$/x-scheme-handler\/magnet=qbt-magnet.desktop/' <<< "$rewritten")"
  expect "the file as the app left it is kept" "$(cat "$mimeapps.pre-nix")" "$rewritten"
  settled=$(cat "$mimeapps")
  expect "plan lists nothing once the file is settled" "$(${both.plan})" "  none"
  ( set -euo pipefail; source ${both.activation} )
  expect "a second switch changes nothing" "$(cat "$mimeapps")" "$settled"
  expect "and keeps the first copy" "$(cat "$mimeapps.pre-nix")" "$rewritten"
  printf '%s\n' '[Default Applications]' x-scheme-handler/magnet=qbt-magnet.desktop x-scheme-handler/magnet=qbt-magnet.desktop text/html=browser.desktop > "$mimeapps"
  ( set -euo pipefail; source ${both.activation} )
  expect "a key the file holds twice is kept once, where it first was" "$(cat "$mimeapps")" \
    "$(printf '%s\n' '[Default Applications]' x-scheme-handler/magnet=qbt-magnet.desktop text/html=browser.desktop)"
  printf '%s\n' '[Default Applications]' text/html=other.desktop > "$mimeapps"
  ( set -euo pipefail; source ${both.activation} )
  expect "lines the text starts the file with are not enforced" "$(sed -n 2p "$mimeapps")" text/html=other.desktop
  ( set -euo pipefail; source ${seedOnly.activation} )
  expect "a line the flake set and no longer declares goes" "$(cat "$mimeapps")" "$(printf '%s\n' '[Default Applications]' text/html=other.desktop)"
  ( set -euo pipefail; source ${both.activation} )
  sed -i 's/=qbt-magnet.desktop$/=chosen.desktop/' "$mimeapps"
  ( set -euo pipefail; source ${seedOnly.activation} )
  expect "a line the flake set and the user changed stays when the flake stops declaring it" "$(sed -n 3p "$mimeapps")" x-scheme-handler/magnet=chosen.desktop

  echo "not json" > "$HOME/merged.json"
  activate
  expect "invalid JSON is left as it is" "$(cat "$HOME/merged.json")" "not json"
  expect "no temp files stay behind" "$(find "$HOME" -name '*.??????' | wc -l | tr -d ' ')" "0"
  touch $out
''
