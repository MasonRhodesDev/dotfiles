{
  name = "AWS CLI";
  description = "awscli2 and saml2aws.";
  platforms = [ "linux" "darwin" ];
  when.profile = "work";

  home = { pkgs, ... }: {
    home.packages = [ pkgs.awscli2 pkgs.saml2aws ];
  };

  inventory = {
    packages = {
      linux = [ "awscli2" "saml2aws" ];
      darwin = [ "awscli2" "saml2aws" ];
    };
  };
}
