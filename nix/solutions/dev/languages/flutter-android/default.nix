{
  name = "Flutter and Android";
  description = "Session-wide Android SDK and Flutter env, ae wrapper.";
  platforms = [ "linux" ];
  when.headless = false;

  linux.home = { config, lib, machine, ... }:
    let withHome = file: builtins.replaceStrings [ "@home@" ] [ config.home.homeDirectory ] (builtins.readFile file); in
    {
      home.file.".bashrc.d/android.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./android.bashrc; };
      xdg.configFile."environment.d/android.conf".text = withHome ./android.conf;
      xdg.configFile."environment.d/flutter.conf".text = withHome ./flutter.conf;
      dotfiles.fragments."hypr/local.lua" = lib.mkIf (lib.elem "window-manager" machine.enabled) ''
        hl.window_rule({ name = "android-emulator", match = { class = "^(Emulator)$" }, float = true })
      '';
    };

  inventory = {
    files = [
      ".bashrc.d/android.bashrc"
      ".config/environment.d/android.conf"
      ".config/environment.d/flutter.conf"
      ".config/hypr/local.lua#android-emulator"
    ];
  };
}
