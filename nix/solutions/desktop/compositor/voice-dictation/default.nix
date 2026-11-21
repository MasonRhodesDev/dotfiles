{
  name = "Voice dictation";
  description = "Whisper dictation (hypr-DE's optional voice-dictation app), idle-prioritised at login, typing with wtype, toggled by a bind. Its overlay is a layer-shell surface, so no window rule places it.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.home = { ... }: {
    dotfiles.fragments."hypr/local.lua" = ''
      hl.bind("CTRL + ALT + SHIFT + v", hl.dsp.exec_cmd("voice-dictation toggle"), { desc = "System: Voice dictation" })
    '';
    xdg.configFile."systemd/user/voice-dictation.service.d/50-login-storm.conf".source = ./50-login-storm.conf;
    xdg.configFile."systemd/user/voice-dictation.service.d/50-log-level.conf".source = ./50-log-level.conf;
  };

  inventory = {
    files = [
      ".config/hypr/local.lua#voice-dictation"
      ".config/systemd/user/voice-dictation.service.d/50-login-storm.conf"
      ".config/systemd/user/voice-dictation.service.d/50-log-level.conf"
    ];
    packages = {
      linux = [ "voice-dictation" ];
    };
  };
}
