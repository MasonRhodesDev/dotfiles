{
  name = "SSH";
  description = "Owns ~/.ssh/config and Host *, with per-host entries from the private repo. On a graphical machine also the agent: on Linux ssh-agent.socket and the env that points shells and GUI apps at it, on darwin launchd's own agent with UseKeychain.";
  platforms = [ "linux" "darwin" ];

  home = { lib, machine, ... }: {
    home.activation.sshDirMode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run mkdir -p "$HOME/.ssh"
      run chmod 700 "$HOME/.ssh"
    '';
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = machine.private.ssh or { } // {
        "*" = {
          IdentityFile = "~/.ssh/id_ed25519";
          IdentitiesOnly = lib.mkDefault true;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        } // lib.optionalAttrs (!machine.traits.headless) {
          AddKeysToAgent = "yes";
          IdentitiesOnly = false;
        };
      };
    };
  };

  linux.home = { lib, pkgs, machine, ... }: lib.mkIf (!machine.traits.headless) {
    systemd.user.sockets.ssh-agent = {
      Unit = {
        Description = "Socket for the OpenSSH key agent";
        Documentation = "man:ssh-agent(1)";
        ConditionEnvironment = "!SSH_AGENT_PID";
        X-SwitchMethod = "keep-old";
      };
      Socket = {
        ListenStream = "%t/ssh-agent.socket";
        RemoveOnStop = true;
      };
      Install.WantedBy = [ "sockets.target" ];
    };
    systemd.user.services.ssh-agent = {
      Unit = {
        Description = "OpenSSH key agent";
        Documentation = "man:ssh-agent(1)";
        ConditionEnvironment = "!SSH_AGENT_PID";
        Requires = [ "ssh-agent.socket" ];
        X-SwitchMethod = "keep-old";
      };
      Service = {
        ExecStart = "${pkgs.openssh}/bin/ssh-agent -D";
        SuccessExitStatus = 2;
      };
    };
    home.file.".bashrc.d/ssh.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./ssh.bashrc; };
    xdg.configFile."environment.d/ssh-agent.conf".source = ./ssh-agent.conf;
  };

  darwin.home = { lib, machine, ... }: lib.mkIf (!machine.traits.headless) {
    programs.ssh.settings."*" = {
      IgnoreUnknown = "UseKeychain";
      UseKeychain = "yes";
    };
    home.file.".bashrc.d/ssh.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { text = ''
      ssh-add -l > /dev/null 2>&1 || /usr/bin/ssh-add --apple-load-keychain > /dev/null 2>&1
    ''; };
  };
}
