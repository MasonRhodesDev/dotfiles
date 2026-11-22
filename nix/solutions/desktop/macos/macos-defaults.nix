let
  disabledHotkeys = [
    { id = 32; name = "kCGSHotKeyExposeAllWindows"; chord = "Ctrl+Up"; why = "Mission Control; terminals and editors use Ctrl+Up"; }
    { id = 33; name = "kCGSHotKeyExposeApplicationWindows"; chord = "Ctrl+Down"; why = "App windows; terminals and editors use Ctrl+Down"; }
    { id = 60; name = "kCGSHotKeySelectPreviousInputSource"; chord = "Ctrl+Space"; why = "one layout; terminals and editors use Ctrl+Space"; }
    { id = 61; name = "kCGSHotKeySelectNextInputSource"; chord = "Ctrl+Opt+Space"; why = "one layout"; }
    { id = 64; name = "kCGSHotKeySpotlightSearchField"; chord = "Cmd+Space"; why = "Raycast takes Cmd+Space (launcher)"; }
    { id = 79; name = "kCGSHotKeySpaceLeft"; chord = "Ctrl+Left"; why = "AeroSpace replaces Spaces; shells move by word on Ctrl+Left"; }
    { id = 80; name = "kCGSHotKeySpaceLeftSlow"; chord = "Ctrl+Shift+Left"; why = "as above"; }
    { id = 81; name = "kCGSHotKeySpaceRight"; chord = "Ctrl+Right"; why = "AeroSpace replaces Spaces; shells move by word on Ctrl+Right"; }
    { id = 82; name = "kCGSHotKeySpaceRightSlow"; chord = "Ctrl+Shift+Right"; why = "as above"; }
  ];
in
{
  name = "macOS defaults";
  description = ''
    nix-darwin system.defaults for a keyboard-driven desktop: fast key repeat, no press-and-hold, Dock autohide, reduced motion, Ctrl+Cmd+drag moves windows, one Space across displays, and the system hotkeys that would take Linux-style chords turned off.
    `nix/bootstrap` sets up a fresh Mac. Reduce motion needs Full Disk Access for the terminal that runs the switch, and is skipped with a warning without it. One Space across displays takes effect at the next login.'';
  platforms = [ "darwin" ];

  darwin.system = { config, lib, ... }: {
    system.defaults = {
      NSGlobalDomain = {
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        ApplePressAndHoldEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSWindowShouldDragOnGesture = true;
      };
      dock = {
        autohide = true;
        mru-spaces = false;
        expose-group-apps = true;
      };
      spaces.spans-displays = true;

      CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys =
        lib.listToAttrs (map (h: lib.nameValuePair (toString h.id) { enabled = false; }) disabledHotkeys);
    };

    system.activationScripts.postActivation.text = ''
      asUser() {
        launchctl asuser "$(id -u -- ${lib.escapeShellArg config.system.primaryUser})" \
          sudo --user=${lib.escapeShellArg config.system.primaryUser} -- "$@"
      }
      asUser /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
      if ! asUser defaults write com.apple.universalaccess reduceMotion -bool true 2>/dev/null; then
        echo "warning: reduce motion not set: the terminal running the switch needs Full Disk Access. Grant it, or turn on System Settings > Accessibility > Display > Reduce motion." >&2
      fi
    '';
  };
}
