{
  name = "MongoDB";
  description = "The mongosh shell.";
  platforms = [ "linux" "darwin" ];
  when.profile = "work";

  home = { pkgs, ... }: {
    home.packages = [ pkgs.mongosh ];
  };
}
