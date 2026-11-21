{
  name = "FW16 internal panel pin";
  description = "Pins workspace 9 to the internal panel, named in the machine entry.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.home = { lib, machine, ... }: {
    dotfiles.fragments."hypr/local.lua" = lib.mkIf (machine.private ? internalPanel) ''
      hl.workspace_rule({ workspace = "9", monitor = "${machine.private.internalPanel}" })
    '';
  };

  inventory = {
    files = [ ".config/hypr/local.lua#fw16-edp2-pin" ];
  };
}
