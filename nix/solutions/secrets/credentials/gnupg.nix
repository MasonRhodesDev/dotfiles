{
  name = "GnuPG";
  description = "gpg common.conf (dir 0700).";
  platforms = [ "linux" "darwin" ];

  home = { lib, ... }: {
    home.activation.gnupgHome = lib.hm.dag.entryBetween [ "dotfilesMutable" ] [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.gnupg"
      run chmod 700 "$HOME/.gnupg"
    '';
    dotfiles.mutable.".gnupg/common.conf" = { strategy = "overwrite"; mode = "0600"; text = "use-keyboxd\n"; };
  };

  darwin.home = { pkgs, ... }: {
    home.packages = [ pkgs.gnupg ];
  };
}
