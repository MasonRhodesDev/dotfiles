{
  name = "AWS CLI";
  description = "awscli2 and saml2aws.";
  platforms = [ "linux" "darwin" ];
  when.profile = "work";

  home = { pkgs, ... }: {
    home.packages = [ pkgs.awscli2 pkgs.saml2aws ];
  };
}
