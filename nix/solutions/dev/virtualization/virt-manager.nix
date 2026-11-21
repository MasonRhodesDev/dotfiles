{
  name = "virt-manager";
  description = "The graphical libvirt client.";
  platforms = [ "linux" ];
  when.headless = false;
  requires = [ "qemu" ];

  linux.root.packages = {
    arch = [ "virt-manager" ];
    fedora = [ "virt-manager" ];
  };

  inventory = {
    packages = {
      linux = [ "virt-manager" ];
    };
  };
}
