{
  system = "x86_64-linux";
  traits = { headless = true; form = "server"; profile = "work"; secrets = "bitwarden"; uses = [ "dev" ]; };
  user = { name = "alex"; home = "/home/alex"; };
  private.bitwarden = {
    envProject = "00000000-0000-4000-8000-0000000000e1";
    secretsProject = "00000000-0000-4000-8000-0000000000e2";
    serverUrl = "https://vault.example.invalid";
  };
}
