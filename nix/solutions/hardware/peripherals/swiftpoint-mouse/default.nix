{
  name = "Swiftpoint mouse";
  description = "Profile OSD and the F20 bind.";
  platforms = [ "linux" ];
  when.hardware = "swiftpoint-mouse";
  requires = [ "window-manager" ];

  linux.home = { lib, ... }: {
    home.file.".local/bin/swiftpoint-profile-osd" = { source = ./swiftpoint-profile-osd; executable = true; };
    dotfiles.fragments."hypr/local.lua" = lib.mkOrder 1550 ''

      hl.bind("F20", hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/swiftpoint-profile-osd"), { desc = "Mouse: Show Swiftpoint profile" })
    '';
  };

  inventory = {
    files = [ ".local/bin/swiftpoint-profile-osd" ".config/hypr/local.lua#swiftpoint-f20" ];
  };
}
