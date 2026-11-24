{ lib, aerospace ? "/opt/homebrew/bin/aerospace", path ? "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin" }:
let
  keymap = import ./keymap.nix;

  parse = chord:
    let parts = lib.splitString " + " chord; in
    { mods = lib.init parts; key = lib.last parts; };

  aerospaceKey = lib.toLower;
  remapKey = key: { minus = "-"; equal = "="; slash = "/"; }.${key} or (lib.toLower key);
  remapMods = mods: lib.sort lib.lessThan (map lib.toLower (lib.remove "SUPER" mods));

  appleKeys = {
    F1 = { name = "brightnessdown"; label = "brightness down"; systemKey = "BRIGHTNESS_DOWN"; };
    F2 = { name = "brightnessup"; label = "brightness up"; systemKey = "BRIGHTNESS_UP"; };
    F3 = { name = "missioncontrol"; label = "Mission Control"; keyCode = 160; };
    F4 = { name = "spotlight"; label = "Spotlight"; keyCode = 177; };
    F5 = { name = "dictation"; label = "dictation"; keyCode = 176; };
    F6 = { name = "donotdisturb"; label = "Do Not Disturb"; keyCode = 178; };
  };

  hidUsage = { capslock = 57; leftshift = 225; };
  keyboardUsage = name: 30064771072 + hidUsage.${name};
  userKeyMapping = [
    { HIDKeyboardModifierMappingSrc = keyboardUsage "capslock"; HIDKeyboardModifierMappingDst = keyboardUsage "leftshift"; }
  ];

  viaSuper = b: b ? aerospace && lib.elem "SUPER" (parse b.hypr).mods;
  wm = lib.filter (b: b ? aerospace) keymap;
  onAppleKey = lib.filter (b: b ? mac && b.mac ? run) keymap;
  fnRule = b:
    let p = parse b.mac.chord; in
    { key = appleKeys.${p.key}.name or (remapKey p.key); mods = lib.sort lib.lessThan (map lib.toLower p.mods); };
  taken = lib.filter viaSuper wm;

  terminals = [
    "net.kovidgoyal.kitty"
    "net.kovidgoyal.kitty-quick-access"
    "com.apple.Terminal"
    "com.github.wez.wezterm"
    "com.mitchellh.ghostty"
  ];

  actionOf = b:
    if lib.hasPrefix "exec-and-forget " b.aerospace then
      { run = [ "/bin/bash" "-c" (lib.removePrefix "exec-and-forget " b.aerospace) ]; }
    else
      { run = [ aerospace ] ++ lib.splitString " " b.aerospace; };

  remap = {
    inherit path terminals;
    ctrlToCmd = "abcdefghijklmnopqrstuvwxyz";
    super = map
      (b: let p = parse b.hypr; in { key = remapKey p.key; mods = remapMods p.mods; desc = "${b.desc} (${b.hypr})"; } // actionOf b)
      taken;
    fn = map (b: fnRule b // { desc = "${b.desc} (${b.mac.chord})"; run = [ "/bin/bash" "-c" b.mac.run ]; }) onAppleKey;
    appleKeys = {
      keyCodes = lib.listToAttrs (map (k: lib.nameValuePair (toString k.keyCode) k.name) (lib.filter (k: k ? keyCode) (lib.attrValues appleKeys)));
      systemKeys = lib.listToAttrs (map (k: lib.nameValuePair k.systemKey k.name) (lib.filter (k: k ? systemKey) (lib.attrValues appleKeys)));
    };
  };

  aerospaceBindings = lib.listToAttrs (map
    (b: let p = parse b.hypr; in
      lib.nameValuePair (lib.concatStringsSep "-" (map lib.toLower p.mods ++ [ (aerospaceKey p.key) ])) b.aerospace)
    (lib.filter (b: !viaSuper b) wm));

  usual = {
    "Cmd+Q" = "Quit app";
    "Cmd+C" = "Copy";
    "Cmd+E" = "Use selection for Find";
    "Cmd+V" = "Paste";
    "Cmd+R" = "Reload (browsers)";
    "Cmd+J" = "Downloads (browsers)";
    "Cmd+F" = "Find";
    "Cmd+Left" = "Start of line";
    "Cmd+Right" = "End of line";
    "Cmd+Up" = "Top of document";
    "Cmd+Down" = "End of document";
    "Cmd+Shift+Left" = "Select to start of line";
    "Cmd+Shift+Right" = "Select to end of line";
    "Cmd+Shift+Up" = "Select to top";
    "Cmd+Shift+Down" = "Select to end";
    "Cmd+0" = "Actual size (zoom reset)";
    "Cmd+Shift+3" = "Screenshot of the screen";
    "Cmd+Shift+4" = "Screenshot of a region";
    "Cmd+Shift+5" = "Screenshot and recording toolbar";
    "Cmd+S" = "Save";
    "Cmd+Shift+S" = "Save As or Duplicate";
    "Cmd+Shift+=" = "Zoom in (some apps)";
    "Cmd+L" = "Address bar (browsers)";
    "Cmd+M" = "Minimize window";
    "Cmd+T" = "New tab";
    "Cmd+/" = "Toggle comment (editors)";
    "Cmd+D" = "Bookmark (browsers), Duplicate (Finder)";
    "Cmd+W" = "Close window or tab";
    "Cmd+H" = "Hide app";
    "Cmd+Tab" = "App switcher";
    "Cmd+Space" = "Spotlight. macos-defaults turns that off, and Raycast's hotkey takes it";
    "Cmd+`" = "Next window of the app";
    "Cmd+N" = "New window";
    "Cmd+P" = "Print";
    "Cmd+Z" = "Undo";
    "Cmd+X" = "Cut";
    "Cmd+A" = "Select all";
    "Cmd+Shift+/" = "Search the Help menu";
    "Cmd+Shift+V" = "Paste and match style";
    "Ctrl+Cmd+Q" = "Lock screen";
  } // lib.listToAttrs (map (n: lib.nameValuePair "Cmd+${n}" "Tab ${n} (browsers, terminals)") (map toString (lib.range 1 9)));

  pretty = chord:
    let
      p = parse chord;
      modName = { CTRL = "Ctrl"; SUPER = "Cmd"; CMD = "Cmd"; ALT = "Opt"; SHIFT = "Shift"; };
      order = [ "CTRL" "SUPER" "CMD" "ALT" "SHIFT" ];
      keyName = {
        slash = "/"; minus = "-"; equal = "="; space = "Space";
        left = "Left"; right = "Right"; up = "Up"; down = "Down";
      }.${p.key} or (if builtins.match "[a-z]" p.key != null then lib.toUpper p.key else p.key);
    in
    lib.concatStringsSep "+" (map (m: modName.${m}) (lib.filter (m: lib.elem m p.mods) order) ++ [ keyName ]);
  physical = b: pretty b.hypr;
  isLetter = key: builtins.match "[A-Za-z]" key != null;
  original = b:
    let p = parse b.hypr; others = lib.remove "SUPER" p.mods; in
    if isLetter p.key && lib.all (m: m == "SHIFT") others
    then "Ctrl${lib.concatMapStrings (_: "+Shift") others}+${p.key} in GUI apps, or right Cmd"
    else "right Cmd";

  takenChords = map physical taken;

  category = b: lib.head (lib.splitString ": " b.desc);
  action = b: lib.concatStringsSep ": " (lib.tail (lib.splitString ": " b.desc));
  onMac = b:
    if b ? unsupported then "not on macOS: ${b.unsupported}"
    else if b ? mac && !(b ? hypr) then (if b.mac ? does then "left to macOS: ${b.mac.does}" else "macOS only")
    else if b ? mac then pretty b.mac.chord + lib.optionalString (appleKeys ? ${(parse b.mac.chord).key}) ", the ${appleKeys.${(parse b.mac.chord).key}.label} key"
    else "";
  row = b: "| ${pretty (b.hypr or b.mac.chord)} | ${action b} | ${onMac b} |";

  cheatsheet = "# Keys\n\n" + ''
    Super is the left Cmd key. Right Cmd stays a plain Cmd. Caps Lock is a second Shift key. Ctrl+letter does what Cmd+letter does on a stock Mac, except in kitty, Terminal, WezTerm and Ghostty.
    ${lib.concatStrings (lib.mapAttrsToList
      (name: binds: "\n## ${name}\n\n| Keys | Action | On macOS |\n| --- | --- | --- |\n${lib.concatMapStrings (b: row b + "\n") binds}")
      (lib.groupBy category keymap))}
    ## Chords taken from macOS and apps

    Hammerspoon catches these on the left Cmd key before any app sees them. In a password field macOS pauses it, so there left Cmd is a plain Cmd and Ctrl is a plain Ctrl.

    | Left Cmd chord | Usually | Now | The original is on |
    | --- | --- | --- | --- |
    ${lib.concatMapStrings
      (b: "| ${physical b} | ${usual.${physical b} or "nothing common"} | ${action b} | ${original b} |\n")
      (lib.filter (b: usual ? ${physical b}) taken)}
    The keymap also takes ${lib.concatStringsSep ", " (lib.filter (c: !(usual ? ${c})) takenChords)}, which no common app uses.

    ## Left alone

    | Chord | Does |
    | --- | --- |
    ${lib.concatMapStrings (c: "| ${c} | ${usual.${c}} |\n")
      (lib.filter (c: !(lib.elem c takenChords)) (lib.attrNames usual))}
    ## Ctrl outside terminals

    Ctrl+letter and Ctrl+Shift+letter become Cmd+letter in every app but the terminals above, so the Cocoa text keys (Ctrl+A, Ctrl+E, Ctrl+K and the rest) only work in terminals. Ctrl with Opt or Cmd is left alone, so Ctrl+Cmd+Q still locks the screen.

    AeroSpace binds these directly, so no app receives them:

    ${lib.concatMapStrings (b: "- ${pretty b.hypr}: ${action b}\n")
      (lib.filter (b: !viaSuper b) wm)}'';

  problems =
    lib.concatMap
      (b: lib.optional (aerospaceBindings.${lib.concatStringsSep "-" (map lib.toLower (parse b.hypr).mods ++ [ (aerospaceKey (parse b.hypr).key) ])} or null != b.aerospace)
        "${b.hypr}: AeroSpace does not bind it directly")
      (lib.filter (b: !viaSuper b) wm)
    ++ map (name: "AeroSpace binds ${name}, which Ctrl+${lib.last (lib.splitString "-" name)} produces in GUI apps")
      (lib.filter (name: builtins.match "cmd(-shift)?-[a-z]" name != null) (lib.attrNames aerospaceBindings));

  fnCase = b:
    let rule = fnRule b; in
    { name = b.mac.chord; key = (parse b.mac.chord).key; cmd = lib.elem "cmd" rule.mods; shift = lib.elem "shift" rule.mods; ctrl = lib.elem "ctrl" rule.mods; alt = lib.elem "alt" rule.mods; arg = [ "/bin/bash" "-c" b.mac.run ]; };

  cases.fn = map fnCase onAppleKey;
  cases.userKeyMapping = userKeyMapping;
  cases.super = map
    (b:
      let p = parse b.hypr; mods = remapMods p.mods; in
      {
        name = b.hypr;
        key = remapKey p.key;
        ctrl = lib.elem "ctrl" mods;
        alt = lib.elem "alt" mods;
        shift = lib.elem "shift" mods;
        arg =
          if lib.hasPrefix "exec-and-forget " b.aerospace then [ "/bin/bash" "-c" (lib.removePrefix "exec-and-forget " b.aerospace) ]
          else [ aerospace ] ++ lib.splitString " " b.aerospace;
      })
    taken;
in
{
  inherit aerospaceBindings remap cheatsheet problems cases userKeyMapping;

  hyprLines = lib.concatMapStrings (b: "${b.hypr}\t${b.desc}\n") (lib.filter (b: b ? hypr) keymap);
}
