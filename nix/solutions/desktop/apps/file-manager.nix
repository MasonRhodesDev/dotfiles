{
  name = "Nautilus";
  description = "File manager.";
  platforms = [ "linux" ];

  linux.root.packages = {
    arch = [ "nautilus" ];
    fedora = [ "nautilus" ];
  };
}
