{
  name = "Launcher";
  description = "Linux: fuzzel, bound to SUPER+R by hypr-DE; the first switch sets hyprlauncher's config aside. darwin: Raycast (cask, login item, Cmd+Space hotkey).";
  platforms = [ "linux" "darwin" ];
  requires = [ "window-manager" ];

  linux.root.packages = {
    arch = [ "fuzzel" ];
    fedora = [ "fuzzel" ];
  };

  darwin.system = {
    homebrew.casks = [ "raycast" ];
    system.defaults.CustomUserPreferences."com.raycast.macos".raycastGlobalHotkey = "Command-49";
  };
}
