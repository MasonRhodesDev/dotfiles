{
  name = "Terminal header";
  description = "Live pane headers (cwd, ssh, agent sections) drawn in kitty's tab bar by a custom tab bar and a watcher that redraws it when a pane's user variables change. The kitty part comes only where kitty is.";
  platforms = [ "linux" "darwin" ];
  when.headless = false;
  requires = [ "node" ];

  home = { lib, machine, ... }: lib.mkIf (lib.elem "kitty" machine.enabled) {
    home.file.".config/kitty/tab_bar.py".source = ./tab_bar.py;
    home.file.".config/kitty/watcher.py".source = ./watcher.py;
    dotfiles.fragments."kitty/kitty.conf" = lib.mkBefore ''
      tab_bar_edge      top
      tab_bar_style     custom
      tab_bar_min_tabs  9999
      tab_bar_align     left

      watcher watcher.py
    '';
  };

  linux.home = { config, ... }:
    let home = config.home.homeDirectory; in
    {
      home.file."scripts/terminal-header" = { source = ./src; recursive = true; };

      dotfiles.services.terminal-header = {
        description = "Terminal header resolver (sections FSM for kitty)";
        command = [ "${home}/.local/share/fnm/aliases/default/bin/node" "${home}/scripts/terminal-header/daemon.ts" ];
        requiresFile = ".local/share/fnm/aliases/default/bin/node";
        systemd.Service = {
          Nice = 19;
          IOSchedulingClass = "idle";
          MemoryHigh = "256M";
          MemoryMax = "512M";
        };
      };
    };

  checks = { pkgs, ... }: {
    terminal-header-resolver = pkgs.runCommand "terminal-header-resolver" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
      cp -r ${./src} src
      cp ${./test.ts} test.ts
      HOME=/home/alex node test.ts
      touch $out
    '';
  };

  inventory = {
    starts = {
      linux = [ "terminal-header.service" ];
    };
    files = [
      ".config/kitty/tab_bar.py"
      ".config/kitty/watcher.py"
      ".config/kitty/kitty.conf#terminal-header"
      ".config/systemd/user/terminal-header.service"
      "scripts/terminal-header/daemon.ts"
      "scripts/terminal-header/resolver.ts"
      "scripts/terminal-header/types.ts"
      "scripts/terminal-header/sections/agent.ts"
      "scripts/terminal-header/sections/cwd.ts"
      "scripts/terminal-header/sections/ssh.ts"
      "scripts/terminal-header/targets/index.ts"
      "scripts/terminal-header/targets/kitty.ts"
      "scripts/terminal-header/targets/util.ts"
    ];
  };
}
