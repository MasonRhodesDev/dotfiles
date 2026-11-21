{
  name = "Work Mac server over SSH";
  description = "ssh Host work-mac for the headless work Mac server, reached over the work tailnet. Its address and user come from the private repo; without them there is no Host.";
  platforms = [ "linux" "darwin" ];
  when.profile = "work";
  requires = [ "ssh" ];

  home = { lib, machine, ... }:
    let server = machine.private.workMacServer or null; in
    {
      programs.ssh.settings = lib.mkIf (server != null) {
        work-mac = {
          HostName = server.tailnetAddress;
          HostKeyAlias = "work-mac";
          User = server.user;
          ConnectTimeout = 10;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };
      };
    };

  inventory = {
    files = [ ".ssh/config#work-mac" ];
  };
}
