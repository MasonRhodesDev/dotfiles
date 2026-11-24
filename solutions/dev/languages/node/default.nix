{
  name = "Node (fnm)";
  description = "fnm-managed Node, npm config, pnpm path.";
  platforms = [ "linux" "darwin" ];

  home = { pkgs, lib, machine, identity, ... }: {
    dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen fnm       fnm completions --shell bash\ngen pnpm      pnpm completion bash\n";
    home.packages = [ pkgs.fnm ];
    dotfiles.credentials."github/packages-token" = {
      description = "GitHub token that ~/.npmrc hands to npm.pkg.github.com. Without a stored one, it is derived from gh's own login.";
      to = "npm";
      deliver.session = "NODE_AUTH_TOKEN";
      derive = "gh auth token";
    };
    home.file.".bashrc.d/node.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./node.bashrc; };
    dotfiles.mutable.".npmrc" = {
      strategy = "seed";
      mode = "0600";
      text = ''
        init-author-name=${identity.name}
        init-author-email=${if lib.elem "work-identity" machine.enabled then identity.emails.work else identity.emails.personal}
        //npm.pkg.github.com/:_authToken=''${NODE_AUTH_TOKEN}
      '';
    };
  };

  linux.home = { config, ... }: {
    xdg.configFile."environment.d/pnpm.conf".text =
      builtins.replaceStrings [ "@home@" ] [ config.home.homeDirectory ] (builtins.readFile ./pnpm.conf);
  };
}
