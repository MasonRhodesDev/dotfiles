{
  name = "Notifications";
  description = "swaync. darwin uses Notification Center.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.root.packages = {
    arch = [ "swaync" ];
    fedora = [ "SwayNotificationCenter" ];
  };
}
