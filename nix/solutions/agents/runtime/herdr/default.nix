let
  herdrOf = pkgs: pkgs.writeShellScript "herdr" ''
    for bin in "$HOME/.local/bin/herdr" /opt/homebrew/bin/herdr /usr/local/bin/herdr /usr/bin/herdr; do
      [ -x "$bin" ] && exec "$bin" "$@"
    done
    echo "herdr is not installed" >&2
    exit 127
  '';
in
{
  name = "herdr";
  description = "Terminal workspace server for coding agents, with a node on its PATH for its plugins on Linux and the memory cap the machine entry states. darwin installs it from Homebrew.";
  platforms = [ "linux" "darwin" ];

  home = { pkgs, config, lib, machine, ... }:
    let
      herdr = herdrOf pkgs;
      socket = "${config.home.homeDirectory}/.config/herdr/herdr.sock";
    in
    {
      dotfiles.services.herdr = {
        description = "Persistent terminal workspace server for coding agents";
        command = [ "${herdr}" "server" ];
        extraPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];
        systemd = {
          Unit = {
            After = [ "graphical-session.target" ];
            StartLimitIntervalSec = 60;
            StartLimitBurst = 3;
          };
          Service = {
            ExecCondition = "${pkgs.runtimeShell} -c '! ${pkgs.iproute2}/bin/ss -xl | grep -qF ${socket}'";
            ExecStop = "${herdr} server stop";
            Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
            OOMPolicy = "continue";
          };
        };
      };

      dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen herdr     herdr completion bash\n";
      home.file.".bashrc.d/herdr.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./herdr.bashrc; };
      dotfiles.fragments."kitty/kitty.conf" = lib.mkIf (lib.elem "kitty" machine.enabled) (lib.mkAfter ''
        # >>> herdr-radar font block
        symbol_map U+E1A0-U+E1BA Herdr Agent Icons Max
        symbol_map U+E1C0-U+E1C5 Herdr Agent Icons Max
        # <<< herdr-radar font block
      '');
    };

  linux.home = { lib, pkgs, machine, ... }: {
    dotfiles.services.herdr.extraPath = [ "${pkgs.nodejs}/bin" ];
    xdg.configFile."systemd/user/herdr.service.d/memory.conf" = lib.mkIf (machine.private ? herdrMemoryMax) {
      text = "[Service]\nMemoryMax=${machine.private.herdrMemoryMax}\n";
    };
  };

  darwin.home = { config, lib, pkgs, ... }: {
    dotfiles.services.herdr.command = lib.mkForce [
      "${pkgs.writeShellScript "herdr-agent" ''
        while /usr/bin/nc -U "$HOME/.config/herdr/herdr.sock" < /dev/null > /dev/null 2>&1; do sleep 30; done
        exec ${herdrOf pkgs} server
      ''}"
    ];
    dotfiles.services.herdr.launchd.KeepAlive.PathState = {
      "${config.home.homeDirectory}/.local/bin/herdr" = true;
      "/opt/homebrew/bin/herdr" = true;
      "/usr/local/bin/herdr" = true;
    };
  };

  darwin.system.homebrew.brews = [ "herdr" ];
}
