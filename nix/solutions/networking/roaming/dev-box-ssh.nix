{
  name = "Dev box over SSH";
  description = "ssh Host for the dev box with a tailnet Match, and the thin-client section of CLAUDE.md. Addresses from the private repo.";
  platforms = [ "linux" "darwin" ];
  when.uses = "remote-dev";
  requires = [ "ssh" ];

  home = { lib, machine, identity, ... }:
    let
      box = machine.private.devBox;
      owner = lib.head (lib.splitString " " identity.name);
    in
    {
      programs.ssh.settings = {
        dev-over-tailnet = lib.hm.dag.entryBefore [ "dev" ] {
          header = ''Match host dev exec "tailscale status --json 2>/dev/null | grep -q '\"BackendState\": \"Running\"'"'';
          HostName = box.tailnetAddress;
        };
        dev = {
          HostName = box.hostName;
          HostKeyAlias = "dev";
          User = box.user;
          ConnectTimeout = 10;
          ServerAliveInterval = 60;
          ServerAliveCountMax = 3;
        };
      };

      dotfiles.fragments."claude/CLAUDE.md/machine" = lib.mkIf (lib.elem "claude-code" machine.enabled) ''
        ## This machine (${machine.name}) is a thin client
        - ${machine.name} is a laptop on battery. The dev box (herdr machine `dev`, SSH `${box.user}@${box.hostName}`, repos under `~/repos`) is where work runs. Default to opening tasks there, not here.
        - Anything that builds, tests, installs tooling, runs a long agent turn, or edits a repo that exists on dev belongs on dev. Hand it to a Claude session in herdr: `herdr --machine dev tab create --workspace <id> --cwd '~/repos/<repo>' --label <name> --no-focus`, then `herdr --machine dev agent start <name> --kind claude --pane <pane_id>`, then `herdr --machine dev agent prompt <name> "<self-contained brief>"`. Discover workspace ids with `herdr --machine dev workspace list`; put a repo task in that repo's workspace when one exists, otherwise the `repos` workspace. Run `herdr --skill` first if the herdr skill is not in context.
        - A fresh agent on dev stops at Claude Code's folder trust prompt. Say so and let ${owner} accept it unless they have already authorised accepting on their behalf in this conversation.
        - Stays local: dotfiles edits and switches for this machine, inspection of this laptop's hardware, power, desktop session and user services, and short reactive answers. Do not install daemons, timers, language toolchains or build dependencies here.
        - Prefer `ssh dev` for one-off remote commands and herdr agents for anything with more than a few steps. Keep local Claude turns short so the machine can suspend.
      '';
    };

  inventory = {
    files = [ ".ssh/config#dev-box" ".claude/CLAUDE.md#thin-client" ];
  };
}
