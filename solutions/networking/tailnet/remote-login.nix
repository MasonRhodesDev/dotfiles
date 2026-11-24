{
  name = "Remote Login";
  description = "Apple's SSH server on a darwin server, so the tailnet reaches it over SSH. The keys in the private entry's authorizedKeys may log in as the user, and once there is one, passwords may not.";
  platforms = [ "darwin" ];
  when.form = "server";

  darwin.system = { lib, machine, ... }:
    let keys = machine.private.authorizedKeys or [ ]; in
    {
      services.openssh.enable = true;
      users.users.${machine.user.name}.openssh.authorizedKeys.keys = keys;
      services.openssh.extraConfig = lib.mkIf (keys != [ ]) ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
      '';
    };
}
