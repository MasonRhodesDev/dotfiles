{
  name = "Screenshot";
  description = "hypr-DE's snip and record binds (grim, slurp, swappy, hyprpicker), with swappy notes in ~/scripts. darwin uses the OS tools.";
  platforms = [ "linux" ];
  requires = [ "window-manager" ];

  linux.home = { ... }: {
    home.file."scripts/swappy-shortcuts.md".source = ./swappy-shortcuts.md;
    home.file."scripts/swappy-tools-guide.md".source = ./swappy-tools-guide.md;
  };

  linux.root.packages = {
    arch = [ "grim" "slurp" "swappy" "hyprpicker" "wl-clipboard" "gpu-screen-recorder" ];
    fedora = [ "grim" "slurp" "swappy" "hyprpicker" "wl-clipboard" ];
  };
}
