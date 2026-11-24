{
  name = "git";
  description = "gitconfig with includeIf identities from the private repo. GitHub goes over SSH, and with the ssh solution on, git's SSH sessions to github.com share one connection.";
  platforms = [ "linux" "darwin" ];

  home = { lib, identity, machine, ... }: {
    programs.git = {
      enable = true;
      settings = {
        user.name = identity.name;
        user.email = lib.mkDefault identity.emails.personal;
        credential."https://dev.azure.com".useHttpPath = true;
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
        url."git@github.com:".insteadOf = "https://github.com/";
        alias = {
          commit-gen = "!git-commit-gen";
          cg = ''!f() { MSG=$(git-commit-gen) && git commit -F - <<< "$MSG"; }; f'';
        };
      };
      includes =
        map
          (override: {
            inherit (override) condition;
            contents.user = { inherit (identity) name; email = identity.emails.${override.identity}; };
          })
          identity.git.includeIf
        ++ [{ path = "~/.gitconfig-local"; }];
    };

    programs.ssh.settings = lib.mkIf (lib.elem "ssh" machine.enabled) {
      "github.com" = {
        ControlMaster = lib.mkDefault "auto";
        ControlPath = lib.mkDefault "~/.ssh/cm/%C";
        ControlPersist = lib.mkDefault "1h";
      };
    };

    home.activation.sshControlDir = lib.mkIf (lib.elem "ssh" machine.enabled) (lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.ssh/cm"
      run chmod 700 "$HOME/.ssh/cm"
    '');

    dotfiles.mutable.".gitconfig" = {
      strategy = "seed";
      text = "# Machine-local git settings. Tools that run `git config --global` write here.\n";
    };
  };
}
