{
  name = "MCP Hub";
  description = "Aggregates the MCP servers that agent harnesses share behind one local endpoint on port 37373. mcp-hub comes from npm's global prefix. Its server list stays unmanaged in ~/.config/mcphub/config.json, since it holds account details, and the service stays down while that file is missing.";
  platforms = [ "linux" ];
  when.uses = "dev";
  requires = [ "node" ];

  linux.home = { config, pkgs, ... }:
    let
      home = config.home.homeDirectory;
      hub = pkgs.writeShellScript "mcp-hub" ''
        for cli in "$HOME/.npm-global/lib/node_modules/mcp-hub/dist/cli.js" /usr/local/lib/node_modules/mcp-hub/dist/cli.js /usr/lib/node_modules/mcp-hub/dist/cli.js; do
          [ -f "$cli" ] && exec ${pkgs.nodejs}/bin/node "$cli" "$@"
        done
        echo "mcp-hub is not installed: npm install -g mcp-hub" >&2
        exit 127
      '';
    in
    {
      dotfiles.services.mcp-hub = {
        description = "MCP Hub, the MCP server aggregator for agent harnesses";
        command = [ "${hub}" "--port" "37373" "--watch" "--config" "${home}/.config/mcphub/config.json" ];
        requiresFile = ".config/mcphub/config.json";
        extraPath = [ "${home}/.npm-global/bin" ];
        restartSec = 3;
        systemd = {
          Unit.After = [ "network-online.target" ];
          Service.Environment = [ "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus" ];
        };
      };
    };
}
