{
  name = "Keymap";
  description = "keymap.nix feeds AeroSpace binds, the Hammerspoon remapper and the cheatsheet, and a flake check compares it with Hyprland. darwin: Hammerspoon runs the Super binds on the left Cmd key, turns Linux-style Ctrl shortcuts into Cmd outside terminals, and runs the binds on the Apple keys of the function row (screenshot and recording on Mission Control, Raycast on Spotlight, keyboard backlight on Cmd with the brightness keys); a login agent makes Caps Lock a Shift key with hidutil.";
  platforms = [ "linux" "darwin" ];
  requires = [ "window-manager" ];

  darwin.home = { config, lib, osConfig, ... }:
    let
      generated = import ./generate.nix {
        inherit lib;
        aerospace = "${osConfig.homebrew.prefix}/bin/aerospace";
        path = "${osConfig.homebrew.prefix}/bin:${config.home.profileDirectory}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
    in
    {
      programs.aerospace.settings.mode.main.binding = generated.aerospaceBindings;

      home.file.".hammerspoon/init.lua".source = ./init.lua;
      home.file.".hammerspoon/remap.lua".source = ./remap.lua;
      home.file.".hammerspoon/keymap.json".text = builtins.toJSON generated.remap;
      home.file.".hammerspoon/keyboard-backlight.js".source = ./keyboard-backlight.js;

      dotfiles.services.caps-as-shift = {
        description = "Caps Lock is a Shift key";
        command = [ "/usr/bin/hidutil" "property" "--set" (builtins.toJSON { UserKeyMapping = generated.userKeyMapping; }) ];
      };

      dotfiles.services.hammerspoon = {
        description = "Hammerspoon, the keymap's key remapper";
        command = [ "/Applications/Hammerspoon.app/Contents/MacOS/Hammerspoon" ];
        restart = "always";
        launchd.ProcessType = "Interactive";
      };

      home.activation.hammerspoonReload = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
        run /bin/launchctl kickstart -k "gui/$(id -u)/org.nix-community.home.hammerspoon" 2>/dev/null || true
      '';

      xdg.configFile."keymap/cheatsheet.md".text = generated.cheatsheet;
    };

  darwin.system = {
    homebrew.casks = [ "hammerspoon" ];

    system.defaults.CustomUserPreferences."org.hammerspoon.Hammerspoon" = {
      MJShowDockIconKey = false;
      MJShowMenuIconKey = false;
      HSUploadCrashData = false;
      SUEnableAutomaticChecks = false;
    };

    dotfiles.permissions.hammerspoon-accessibility = {
      what = "Accessibility for Hammerspoon";
      pane = "accessibility";
      check = "pgrep -xq Hammerspoon && grep -q '\"accessibility\":true' \"$HOME/.local/state/keymap/remapper.json\"";
    };
  };

  checks = { pkgs, inputs, lib }: {
    keymap-chords =
      let problems = (import ./generate.nix { inherit lib; }).problems; in
      if problems == [ ] then pkgs.runCommand "keymap-chords" { } "touch $out"
      else throw "check keymap-chords failed:\n${lib.concatMapStrings (p: "  - ${p}\n") problems}";

    keymap-remap =
      let generated = import ./generate.nix { inherit lib; }; in
      pkgs.runCommand "keymap-remap"
        {
          nativeBuildInputs = [ pkgs.lua5_4 ];
          config = "return ${lib.generators.toLua { } generated.remap}";
          cases = "return ${lib.generators.toLua { } generated.cases}";
          passAsFile = [ "config" "cases" ];
        } ''
        mkdir run
        cp ${./remap.lua} run/remap.lua
        cp "$configPath" run/config.lua
        cp "$casesPath" run/cases.lua
        lua ${./remap-test.lua} run | tee $out
        luac -p ${./init.lua}
      '';

    keymap-parity = pkgs.runCommand "keymap-parity"
      {
        nativeBuildInputs = [ pkgs.lua5_4 ];
        keymap = (import ./generate.nix { inherit lib; }).hyprLines;
        passAsFile = [ "keymap" ];
      } ''
      LC_ALL=C sort "$keymapPath" > keymap.nix.binds
      lua ${./hl-stub.lua} ${inputs.hypr-de}/dist/hypr/main.lua | LC_ALL=C sort > hypr-de.binds
      if ! diff -u keymap.nix.binds hypr-de.binds; then
        echo "keymap.nix and hypr-DE's main.lua disagree."
        echo "A line with - is only in keymap.nix. A line with + is only in main.lua."
        exit 1
      fi
      wc -l < hypr-de.binds > $out
    '';
  };

  inventory = {
    starts = {
      darwin = [ "launchd: hammerspoon" "launchd: caps-as-shift" ];
    };
    files = [
      "nix:keymap.nix"
      ".hammerspoon/init.lua"
      ".hammerspoon/remap.lua"
      ".hammerspoon/keymap.json"
      ".hammerspoon/keyboard-backlight.js"
      ".config/keymap/cheatsheet.md"
      "nix:homebrew#hammerspoon"
    ];
    packages = {
      darwin = [ "hammerspoon (cask)" ];
    };
  };
}
