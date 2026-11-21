{
  name = "Docker";
  description = "Docker on Linux, colima on darwin.";
  platforms = [ "linux" "darwin" ];

  linux.root = { lib, machine, ... }:
    let user = machine.user.name; in
    {
      packages = {
        arch = [ "docker" ];
        fedora = [ "moby-engine|docker-ce" ];
      };
      units = [ "docker.socket" ];
      files."/etc/systemd/resolved.conf.d/docker.conf" = {
        text = ''
          [Resolve]
          DNSStubListenerExtra=172.17.0.1
        '';
        reload = "systemctl try-reload-or-restart systemd-resolved";
      };
      script = ''
        getent group docker >/dev/null || groupadd --system docker
        case " $(id -nG ${lib.escapeShellArg user}) " in
          *" docker "*) ;;
          *)
            usermod -aG docker ${lib.escapeShellArg user}
            echo "added ${user} to the docker group; it applies at the next login"
            ;;
        esac
      '';
    };

  darwin.home = { pkgs, ... }: {
    home.packages = [ pkgs.colima pkgs.docker-client ];
  };

  inventory = {
    starts = {
      root = [ "docker.socket" ];
    };
    scripts = [
      {
        id = "53-system-session-tweaks:docker-dns";
        root = true;
      }
    ];
    packages = {
      linux = [ "docker" ];
      darwin = [ "colima" "docker (client)" ];
    };
  };
}
