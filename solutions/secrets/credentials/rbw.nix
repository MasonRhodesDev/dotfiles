{
  name = "rbw pinentry";
  description = "pinentry-curses on every machine as a terminal fallback, and, where rbw is installed (by the bitwarden-vault provider or the machine's own package list), rbw set to it on a machine with no graphical session. Login stays manual.";
  platforms = [ "linux" "darwin" ];

  home = { config, lib, pkgs, machine, ... }: {
    home.packages = [ pkgs.pinentry-curses ];
    dotfiles.mutable.${if pkgs.stdenv.hostPlatform.isDarwin then "Library/Application Support/rbw/config.json" else ".config/rbw/config.json"} =
      lib.mkIf (machine.traits.headless && lib.any (p: lib.getName p == "rbw") config.home.packages) {
        strategy = "merge-json";
        mode = "0600";
        json.pinentry = "${pkgs.pinentry-curses}/bin/pinentry-curses";
      };
  };

  darwin.home = { pkgs, ... }: {
    home.packages = [ pkgs.pinentry_mac ];
  };
}
