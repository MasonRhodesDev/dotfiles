{
  name = "lmtt";
  description = "Light/dark theme switcher with matugen colours, the gtk.css overrides that import its colours, a hyprtoolkit module where the window manager is, a kitty module and kitty.conf include where kitty is, and the tmux colours where tmux is.";
  platforms = [ "linux" ];

  linux.home = { lib, machine, ... }:
    let has = id: lib.elem id machine.enabled; in
    lib.mkMerge [
      (lib.mkIf (has "window-manager") {
        xdg.configFile."lmtt/modules/hyprtoolkit.toml".source = ./hyprtoolkit.toml;
        xdg.configFile."lmtt/scripts/hyprtoolkit.sh" = { source = ./hyprtoolkit.sh; executable = true; };
      })
      (lib.mkIf (has "kitty") {
        xdg.configFile."lmtt/modules/kitty.toml".source = ./kitty.toml;
        dotfiles.fragments."kitty/kitty.conf" = "include lmtt-colors.conf\n";
      })
      (lib.mkIf (has "tmux") {
        dotfiles.fragments."tmux/tmux.conf" = "if-shell '[ -f ~/.config/tmux/lmtt-colors.conf ]' 'source-file ~/.config/tmux/lmtt-colors.conf'\n";
      })
      {
        xdg.configFile."gtk-3.0/gtk.css".source = ./gtk3.css;
        xdg.configFile."gtk-4.0/gtk.css".source = ./gtk4.css;
        xdg.dataFile."icons/hicolor/index.theme".source = ./index.theme;
      }
    ];

  linux.root.packages = {
    arch = [ "lmtt" "matugen" ];
    fedora = [ "lmtt" "matugen" ];
  };

  inventory = {
    files = [
      ".config/lmtt/modules/hyprtoolkit.toml"
      ".config/lmtt/modules/kitty.toml"
      ".config/kitty/kitty.conf#lmtt"
      ".tmux.conf#lmtt"
      ".config/lmtt/scripts/hyprtoolkit.sh"
      ".config/gtk-3.0/gtk.css"
      ".config/gtk-4.0/gtk.css"
      ".local/share/icons/hicolor/index.theme"
    ];
    packages = {
      linux = [ "lmtt" "matugen" ];
    };
  };
}
