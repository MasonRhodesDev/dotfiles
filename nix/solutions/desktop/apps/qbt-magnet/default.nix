{
  name = "qBittorrent magnet links";
  description = "Opens magnet: links, as the default handler every switch sets in mimeapps.list, by adding them to the home lab's qBittorrent Web UI, named in the identity's qbittorrent. The Web UI password stays in ~/.config/qbt-magnet/password.";
  platforms = [ "linux" ];
  when.headless = false;
  when.profile = "personal";

  linux.home = { lib, machine, identity, ... }:
    let qbittorrent = identity.qbittorrent or { }; in
    lib.mkMerge [
      {
        home.file.".local/bin/qbt-magnet" = { source = ./qbt-magnet; executable = true; };
        xdg.dataFile."applications/qbt-magnet.desktop".source = ./qbt-magnet.desktop;
        dotfiles.warnings = lib.optional (!(qbittorrent ? url))
          "${machine.name}: the identity sets no qbittorrent.url, so magnet links have no Web UI to go to";
      }
      (lib.mkIf (qbittorrent ? url) {
        xdg.configFile."qbt-magnet/config".text =
          "QBT_URL=${lib.escapeShellArg qbittorrent.url}\n"
          + lib.optionalString (qbittorrent ? user) "QBT_USER=${lib.escapeShellArg qbittorrent.user}\n";
        dotfiles.mutable.".config/mimeapps.list" = {
          strategy = "merge-ini";
          ini."Default Applications"."x-scheme-handler/magnet" = "qbt-magnet.desktop";
        };
      })
    ];

  inventory = {
    files = [ ".local/bin/qbt-magnet" ".local/share/applications/qbt-magnet.desktop" ".config/qbt-magnet/config" ".config/mimeapps.list#qbt-magnet" ];
  };
}
