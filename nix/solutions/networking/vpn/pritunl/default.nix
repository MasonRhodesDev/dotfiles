{
  name = "Pritunl client";
  description = "Pritunl VPN client.";
  platforms = [ "linux" ];
  when.profile = "work";

  linux.home = { ... }: {
    xdg.dataFile."applications/pritunl-client-electron.desktop".source = ./pritunl-client-electron.desktop;
  };

  linux.root = {
    distros = [ "fedora" ];
    repositories.fedora.pritunl = {
      url = "https://repo.pritunl.com/stable/yum/fedora/$releasever/";
      key = {
        url = "https://raw.githubusercontent.com/pritunl/pgp/master/pritunl_repo_pub.asc";
        fingerprint = "7568D9BB55FF9E5287D586017AE645C0CF8E292A";
      };
    };
    packages.fedora = [ "pritunl-client-electron" ];
  };
}
