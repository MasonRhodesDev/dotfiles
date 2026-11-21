{
  name = "Razer devices";
  description = "openrazer driver and Polychromatic.";
  platforms = [ "linux" ];
  when.hardware = "razer";

  linux.root = {
    repositories.fedora.hardware_razer = {
      url = "https://download.opensuse.org/repositories/hardware:/razer/Fedora_$releasever/";
      key = {
        url = "https://build.opensuse.org/projects/hardware/signing_keys/download?kind=gpg";
        fingerprint = "E96C496E4E77C159C2FCA053062F9FD4D6D11CE4";
      };
    };
    packages = {
      arch = [ "openrazer-daemon" ];
      fedora = [ "openrazer-meta" "polychromatic" ];
    };
  };

  inventory = {
    scripts = [
      {
        id = "54-third-party-repos:razer";
        root = true;
        note = "Fedora only";
      }
    ];
    packages = {
      linux = [ "openrazer" "polychromatic (Fedora)" ];
    };
  };
}
