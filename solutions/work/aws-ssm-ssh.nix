{
  name = "SSM ssh";
  description = "ssh ProxyCommand through AWS SSM for i-*/mi-* hosts.";
  platforms = [ "linux" "darwin" ];
  requires = [ "ssh" "aws" ];

  home = { ... }: {
    programs.ssh.settings."i-* mi-*" = {
      ProxyCommand = "~/bin/ssm-proxy %h %p";
      StrictHostKeyChecking = "no";
      UserKnownHostsFile = "/dev/null";
    };
  };
}
