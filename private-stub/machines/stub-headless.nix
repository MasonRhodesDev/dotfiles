{
  system = "x86_64-linux";
  traits = { headless = true; form = "server"; profile = "personal"; secrets = "none"; uses = [ "dev" "agent-hosting" ]; };
  user = { name = "alex"; home = "/home/alex"; };
  private.herdrMemoryMax = "4G";
  private.ephBuildRoot = "/scratch/eph";
}
