{
  system = "aarch64-darwin";
  traits = { headless = false; form = "laptop"; profile = "personal"; secrets = "bitwarden-vault"; uses = [ "remote-dev" ]; };
  user = { name = "alex"; home = "/Users/alex"; };
  private.devBox = { hostName = "dev.example.invalid"; tailnetAddress = "dev-tailnet.example.invalid"; user = "alex"; };
  private.claudeMd = ''
    ## This machine
    - Build output goes to the scratch volume, never the home volume.
  '';
  private.buildHost = "build-host.example.invalid";
}
