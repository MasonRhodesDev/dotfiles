{
  name = "greetd + Vigil";
  description = "greetd configured by greetd_game_mode, Vigil as greeter, device-access groups, seatd umask.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.root.files =
    let dropIn = text: { inherit text; reload = "systemctl daemon-reload"; }; in
    {
      "/etc/systemd/system/greetd.service.d/groups.conf" = dropIn ''
        [Service]
        SupplementaryGroups=seat video input render
      '';
      "/etc/systemd/system/seatd.service.d/umask.conf" = dropIn ''
        [Service]
        UMask=0007
      '';
    };
}
