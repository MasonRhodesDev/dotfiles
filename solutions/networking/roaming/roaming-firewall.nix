{
  name = "Roaming firewall";
  description = "Linux: firewalld zones per Wi-Fi profile, closed on unknown networks; trusted list and per-network zones from the private repo. darwin: macOS application firewall with stealth mode.";
  platforms = [ "linux" "darwin" ];
  when.form = "laptop";

  linux.root = { lib, machine, ... }: {
    packages = {
      arch = [ "firewalld" ];
      fedora = [ "firewalld" ];
    };
    units = [ "firewalld.service" ];
    script = ''
      trusted=(${lib.escapeShellArgs machine.private.trustedNetworks})
      declare -A zones=(${lib.concatStringsSep " " (lib.mapAttrsToList (n: z: "[${lib.escapeShellArg n}]=${lib.escapeShellArg z}") (machine.private.networkZones or { }))})

      for u in nftables iptables; do
        if systemctl is-enabled "$u" >/dev/null 2>&1; then
          systemctl disable --now "$u"
          echo "  disabled $u.service (conflicts with firewalld)"
        fi
      done

      reload=0
      if [ "$(firewall-cmd --get-default-zone)" != public ]; then
        firewall-cmd --set-default-zone=public
        reload=1
      fi
      if firewall-cmd --permanent --zone=public --query-service=ssh >/dev/null 2>&1; then
        firewall-cmd --permanent --zone=public --remove-service=ssh
        reload=1
        echo "  removed ssh from public zone"
      fi
      if [ "$reload" = 1 ]; then firewall-cmd --reload; fi

      command -v nmcli >/dev/null 2>&1 || { echo "nmcli not present; Wi-Fi zones not pinned"; exit 0; }
      while IFS=: read -r name type; do
        [ "$type" = "802-11-wireless" ] || continue
        want=public
        for t in "''${trusted[@]}"; do [ "$name" = "$t" ] && want=trusted; done
        [ -n "''${zones[$name]:-}" ] && want=''${zones[$name]}
        have=$(nmcli -g connection.zone connection show "$name" 2>/dev/null || true)
        if [ "$have" != "$want" ]; then
          nmcli connection modify "$name" connection.zone "$want"
          echo "  $name -> zone $want"
          if nmcli -t -f NAME connection show --active | grep -qx "$name"; then
            nmcli connection up "$name" >/dev/null || true
          fi
        fi
      done < <(nmcli -t -f NAME,TYPE connection show)
    '';
  };

  darwin.system = {
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
    };
  };
}
