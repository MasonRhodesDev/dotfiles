{
  name = "Window borders";
  description = "JankyBorders on darwin, in hypr-DE's border width and colours. Hyprland draws its own borders, so no Linux implementation.";
  platforms = [ "darwin" ];
  requires = [ "window-manager" ];

  darwin.home = {
    services.jankyborders = {
      enable = true;
      settings = {
        style = "round";
        width = 4.0;
        hidpi = "on";
        active_color = "0xffffb77a";
        inactive_color = "0xff9e8e82";
      };
    };
  };
}
