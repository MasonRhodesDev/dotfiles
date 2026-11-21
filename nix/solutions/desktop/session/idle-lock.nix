{
  name = "Idle and lock";
  description = "hypridle against hypr-DE's idle policy, Vigil as the locker, logind idle control, and a fingerprint-then-password PAM stack for hyprlock. darwin uses the OS lock.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.root = {
    packages = {
      arch = [ "hypridle" "vigil" "logind-idle-control" ];
      fedora = [ "hypridle" "vigil" "logind-idle-control" ];
    };
    files."/etc/pam.d/hyprlock".text = ''
      #%PAM-1.0
      auth [success=1 new_authtok_reqd=1 default=ignore] pam_unix.so try_first_pass likeauth nullok
      auth sufficient pam_pcbiounlock.so
      auth        include     login
    '';
  };

  inventory = {
    starts = {
      linux = [ "hypridle.service (hypr-de preset)" "logind-idle-control.service (hypr-de preset)" ];
    };
    scripts = [
      {
        id = "53-system-session-tweaks:pam-hyprlock";
        root = true;
      }
    ];
    packages = {
      linux = [ "hypridle" "hyprlock" "logind-idle-control" ];
    };
  };
}
