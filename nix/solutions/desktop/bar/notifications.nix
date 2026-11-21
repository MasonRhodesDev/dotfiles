{
  name = "Notifications";
  description = "swaync. darwin uses Notification Center.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.root.packages = {
    arch = [ "swaync" ];
    fedora = [ "SwayNotificationCenter" ];
  };

  inventory = {
    starts = {
      linux = [ "swaync.service (hypr-de preset)" ];
    };
    packages = {
      linux = [ "swaync" ];
    };
  };
}
