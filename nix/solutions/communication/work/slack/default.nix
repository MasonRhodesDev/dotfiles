{
  name = "Slack";
  description = "Slack at login, desktop entry, and notify plugins for swaync where the notifications solution is.";
  platforms = [ "linux" "darwin" ];
  requires = [ "window-manager" "keyring@linux" ];

  linux.home = { lib, machine, ... }: lib.mkMerge [
    {
      xdg.dataFile."applications/slack.desktop".source = ./slack.desktop;
      xdg.configFile."autostart/slack.desktop".source = ./slack.desktop;
      dotfiles.fragments."hypr/local.lua" = ''
        hl.window_rule({ name = "slack-special", match = { class = "^(slack)$" }, workspace = "special:magic silent" })
      '';
    }
    (lib.mkIf (lib.elem "notifications" machine.enabled) {
      xdg.configFile."hypr-de/notify-plugins/slack.sh".source = ./slack.sh;
      xdg.configFile."hypr-de/notify-plugins/slack-notification-context.py" = { source = ./slack-notification-context.py; executable = true; };
    })
  ];

  inventory = {
    starts = {
      linux = [ "xdg-autostart: slack.desktop" ];
    };
    files = [
      ".config/autostart/slack.desktop"
      ".local/share/applications/slack.desktop"
      ".config/hypr-de/notify-plugins/slack.sh"
      ".config/hypr-de/notify-plugins/slack-notification-context.py"
      ".config/hypr/local.lua#slack"
    ];
    packages = {
      linux = [ "slack" ];
    };
  };
}
