{
  name = "Tailscale roaming";
  description = "Linux laptop: tailnet up away from home via a NetworkManager dispatcher hook keyed on the connection zone, and tailscale0 in firewalld's trusted zone.";
  platforms = [ "linux" ];
  when.form = "laptop";
  requires = [ "tailscale" "roaming-firewall" ];

  linux.root = { machine, ... }: {
    packages = {
      arch = [ "jq" ];
      fedora = [ "jq" ];
    };

    files."/etc/NetworkManager/dispatcher.d/60-tailscale-by-network" = {
      mode = "0755";
      text = ''
        #!/bin/bash
        [ "$2" = up ] || exit 0
        [ -n "''${CONNECTION_ID:-}" ] || exit 0
        case "$(nmcli -g connection.type connection show "$CONNECTION_ID" 2>/dev/null)" in
            802-11-wireless|802-3-ethernet) ;;
            *) exit 0 ;;
        esac
        zone=$(nmcli -g connection.zone connection show "$CONNECTION_ID" 2>/dev/null || true)
        state=$(tailscale status --json 2>/dev/null | jq -r .BackendState 2>/dev/null || echo unknown)
        if [ "$zone" = trusted ]; then
            if [ "$state" = Running ]; then
                tailscale down && logger -t tailscale-by-network "home network $CONNECTION_ID: tailnet down"
            fi
        else
            case "$state" in
                Running) ;;
                NeedsLogin|unknown)
                    logger -t tailscale-by-network "away on $CONNECTION_ID but tailscale is $state; run: sudo tailscale up --operator=${machine.user.name}" ;;
                *)
                    tailscale up --timeout=30s && logger -t tailscale-by-network "away on $CONNECTION_ID: tailnet up" ;;
            esac
        fi
        exit 0
      '';
    };

    script = ''
      if systemctl is-active --quiet firewalld \
          && ! firewall-cmd --permanent --zone=trusted --query-interface=tailscale0 >/dev/null 2>&1; then
        firewall-cmd --permanent --zone=trusted --add-interface=tailscale0 >/dev/null
        firewall-cmd --reload >/dev/null
      fi
    '';
  };
}
