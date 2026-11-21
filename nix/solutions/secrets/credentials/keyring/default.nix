{
  name = "Desktop keyring";
  description = "Linux: GNOME Keyring as org.freedesktop.secrets, resync after login, git secretservice helper. darwin: macOS Keychain git helper.";
  platforms = [ "linux" "darwin" ];
  when.headless = false;

  linux.root = {
    packages = {
      arch = [ "gnome-keyring" "seahorse" "python-gobject" ];
      fedora = [ "gnome-keyring" "seahorse" "python3-gobject" ];
    };
  };

  linux.home = { ... }: {
    programs.git.settings.credential.credentialStore = "secretservice";

    home.file.".local/bin/keyring-resync" = { source = ./keyring-resync; executable = true; };

    systemd.user.services.keyring-resync = {
      Unit = {
        Description = "Re-key the login keyring if it is still locked after login";
        After = [ "graphical-session.target" "gnome-keyring-daemon.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/keyring-resync --wait 20";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    xdg.dataFile."dbus-1/services/org.freedesktop.secrets.service".text = ''
      [D-BUS Service]
      Name=org.freedesktop.secrets
      Exec=/usr/bin/gnome-keyring-daemon --start --foreground --components=secrets
      SystemdService=gnome-keyring-daemon.service
    '';
  };

  darwin.home = { ... }: {
    programs.git.settings.credential.helper = "osxkeychain";
  };

  inventory = {
    starts = {
      linux = [ "keyring-resync.service" ];
    };
    files = [
      ".config/systemd/user/keyring-resync.service"
      ".local/bin/keyring-resync"
      ".local/share/dbus-1/services/org.freedesktop.secrets.service"
      ".gitconfig#credential-helper"
    ];
    packages = {
      linux = [ "gnome-keyring" "seahorse" "python-gobject" ];
    };
  };
}
