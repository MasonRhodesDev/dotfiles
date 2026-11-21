{
  name = "Atlassian CLI";
  description = "acli.";
  platforms = [ "linux" "darwin" ];

  linux.root = {
    distros = [ "fedora" ];
    repositories.fedora.acli = {
      url = "https://acli.atlassian.com/linux/rpm/";
      metadataSigned = true;
      key = {
        url = "https://acli.atlassian.com/gpg/public-key-rpm.asc";
        fingerprint = "1948EC7C6AEE543502133FAE73D1BEF4F9E55707";
      };
    };
    packages.fedora = [ "acli" ];
  };

  inventory = {
    scripts = [
      {
        id = "54-third-party-repos:acli";
        root = true;
        note = "Fedora only";
      }
    ];
    packages = {
      linux = [ "acli (Fedora)" ];
    };
  };
}
