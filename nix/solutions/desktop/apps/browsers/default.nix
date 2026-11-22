{
  name = "Browsers";
  description = "Linux: Chromium, default-browser guard over mimeapps.list. darwin: Firefox and ungoogled-chromium casks.";
  platforms = [ "linux" "darwin" ];

  linux.home = { lib, machine, ... }: {
    dotfiles.fragments."hypr/local.lua" = lib.mkIf (lib.elem "window-manager" machine.enabled) ''
      hl.window_rule({ name = "keep-tile", match = { title = "^(keep.google.com_/)$" }, tile = true })
      hl.window_rule({ name = "crx-float", match = { title = "^(_crx_nngceckbapebfimnlniiiahkandclblb)$" }, float = true })
    '';
    dotfiles.mutable.".config/mimeapps.list" = { strategy = "merge-ini"; source = ./mimeapps.list; };
    xdg.configFile."chromium-flags.conf".source = ./chromium-flags.conf;
    xdg.dataFile."applications/chromium-browser.desktop".source = ./chromium-browser.desktop;
    home.file.".local/bin/browser-default-guard" = { source = ./browser-default-guard; executable = true; };

    systemd.user.paths.browser-default-guard = {
      Unit.Description = "Watch mimeapps.list for default-browser hijacking (Slack)";
      Path = {
        PathModified = "%h/.config/mimeapps.list";
        TriggerLimitIntervalSec = "10s";
        TriggerLimitBurst = 5;
      };
      Install.WantedBy = [ "default.target" ];
    };
    systemd.user.services.browser-default-guard = {
      Unit.Description = "Reassert Chromium as the default web browser";
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/browser-default-guard";
      };
    };
  };

  linux.root = { ... }: {
    packages = {
      arch = [ "chromium" ];
      fedora = [ "chromium" ];
    };
  };

  darwin.system.homebrew.casks = [ "firefox" "ungoogled-chromium" ];
}
