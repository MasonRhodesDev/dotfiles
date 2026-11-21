{
  name = "Secret inbox";
  description = "Phone form over the tailnet that writes new secrets into the machine's Infisical project, environment and path from ~/.config/infisical/project.json. Its Infisical identity comes from the credential chain as two files written before it starts. Inert without that identity, machine.env or project.json.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "infisical";
  requires = [ "infisical-sync" ];

  home = { pkgs, ... }: {
    dotfiles.credentials = {
      "infisical/inbox-client-id" = {
        description = "Client id of the Infisical identity the secret inbox writes new secrets with.";
        to = "secret-inbox";
        deliver.file = true;
      };
      "infisical/inbox-client-secret" = {
        description = "Client secret of the Infisical identity the secret inbox writes new secrets with.";
        to = "secret-inbox";
        deliver.file = true;
      };
    };

    home.file.".local/bin/secret-inbox" = { source = ./secret-inbox; executable = true; };
    home.file.".local/bin/infisical-ask" = { source = ./infisical-ask; executable = true; };

    dotfiles.services.secret-inbox = {
      description = "Secret inbox: phone form that writes requested secrets to Infisical";
      command = [ "${pkgs.python3}/bin/python3" "${./secret-inbox}" ];
      restartSec = 10;
      requiresFile = [ ".config/infisical/machine.env" ".config/infisical/project.json" ];
      credentials = [ "infisical/inbox-client-id" "infisical/inbox-client-secret" ];
    };
  };

  inventory = {
    starts = {
      linux = [ "secret-inbox.service" ];
      darwin = [ "launchd: secret-inbox (new)" ];
    };
    files = [
      ".config/systemd/user/secret-inbox.service"
      ".local/bin/secret-inbox"
      ".local/bin/infisical-ask"
    ];
  };
}
