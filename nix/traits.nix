{
  headless = {
    description = "No graphical session.";
    values = [ true false ];
  };
  form = {
    description = "What kind of box it is: a laptop on battery, a desktop, or a server.";
    values = [ "laptop" "desktop" "server" ];
  };
  profile = {
    description = "Whose machine it is: the employer's, or the owner's own.";
    values = [ "work" "personal" ];
  };
  secrets = {
    description = "The provider a credential comes from when the machine's local store does not hold it: Infisical, Bitwarden Secrets Manager, the owner's personal Bitwarden vault through rbw or bw, or none. Its CLI is installed only with it. With none, the local store, derive and the manual step remain.";
    values = [ "infisical" "bitwarden" "bitwarden-vault" "none" ];
  };
  uses = {
    description = "What the machine is for: building code, working on another machine over SSH, hosting agents for other machines, games, building iOS apps.";
    values = [ "dev" "remote-dev" "agent-hosting" "gaming" "ios-dev" ];
    many = true;
    default = [ ];
  };
  hardware = {
    description = "Hardware the machine has that needs its own setup.";
    values = [ "framework-16" "swiftpoint-mouse" "zsa-keyboard" "razer" "xbox-controller" "3d-printer" ];
    many = true;
    default = [ ];
  };
}
