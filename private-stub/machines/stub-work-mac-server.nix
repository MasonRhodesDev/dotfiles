{
  system = "aarch64-darwin";
  traits = { headless = true; form = "server"; profile = "work"; secrets = "infisical"; uses = [ "dev" "agent-hosting" "ios-dev" ]; };
  user = { name = "alex"; home = "/Users/alex"; };
  private.authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLEexampleEXAMPLEexampleEXAMPLEexample0 stub-key" ];
  private.infisical = { projectId = "example-project"; environment = "example-env"; path = "/example-path"; };
}
