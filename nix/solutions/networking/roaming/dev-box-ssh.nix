{
  name = "Dev box over SSH";
  description = "ssh Host for the dev box with a tailnet Match. Addresses from the private repo.";
  platforms = [ "linux" "darwin" ];
  when.uses = "remote-dev";
  requires = [ "ssh" ];

  home = { lib, machine, identity, ... }:
    let
      box = machine.private.devBox;
      owner = lib.head (lib.splitString " " identity.name);
    in
    {
      programs.ssh.settings = {
        dev-over-tailnet = lib.hm.dag.entryBefore [ "dev" ] {
          header = ''Match host dev exec "tailscale status --json 2>/dev/null | grep -q '\"BackendState\": \"Running\"'"'';
          HostName = box.tailnetAddress;
        };
        dev = {
          HostName = box.hostName;
          HostKeyAlias = "dev";
          User = box.user;
          ConnectTimeout = 10;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };
      };
    };
}
