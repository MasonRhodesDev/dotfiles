let
  install = { pkgs, home, profile, limit ? 300 }:
    let
      manual = "curl -fsSL https://claude.ai/install.sh | bash";
      installer = pkgs.writeShellScript "claude-install" ''
        dir=$1
        ${pkgs.curl}/bin/curl --proto '=https' --tlsv1.2 -fsSL --max-time 120 https://claude.ai/install.sh -o "$dir/install.sh" || exit 1
        IFS= read -r first < "$dir/install.sh" || true
        case $first in
          "#!"*) ;;
          *) echo "claude-code: the download is not a script (a captive portal answers like this), so it is not run" >&2; exit 1 ;;
        esac
        PATH="${pkgs.curl}/bin:${pkgs.coreutils}/bin:/usr/local/bin:/usr/bin:/bin" ${pkgs.bash}/bin/bash "$dir/install.sh"
      '';
    in
    ''
      if ! (PATH="$PATH:${home}/.local/bin:${profile}/bin:/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin"; command -v claude) > /dev/null 2>&1; then
        claudeInstallDir=
        if claudeInstallDir=$(mktemp -d "''${TMPDIR:-/tmp}/claude-install.XXXXXX") \
          && ${pkgs.coreutils}/bin/timeout ${toString limit} ${installer} "$claudeInstallDir"; then
          echo "claude-code: installed Claude Code"
        else
          echo "claude-code: installing Claude Code failed or took over ${toString limit}s. Run: ${manual}" >&2
        fi
        if [ -n "$claudeInstallDir" ]; then rm -rf "$claudeInstallDir"; fi
      fi
    '';
in
{
  name = "Claude Code config";
  description = "The claude CLI, installed by Anthropic's installer and left to update itself. CLAUDE.md, settings merge, keybindings, agents, references, undercover hooks, and on a work machine the slack-mcp wrapper, which takes Slack's tokens from the credential chain in its environment.";
  platforms = [ "linux" "darwin" ];

  fragments = [ "claude/CLAUDE.md/work" "claude/CLAUDE.md/machine" "claude/CLAUDE.md/private" ];

  home = { config, lib, pkgs, identity, machine, ... }:
    let
      fragment = key: config.dotfiles.fragments.${key} or "";
      work = fragment "claude/CLAUDE.md/work";
      private = fragment "claude/CLAUDE.md/private";
      claudeMd = builtins.replaceStrings
        [ "@work@" "@machine@" "@private@\n" "@firstName@" ]
        [
          (if work == "" then "\n" else "\n${work}\n")
          (fragment "claude/CLAUDE.md/machine")
          (if private == "" then "" else "\n${private}")
          (lib.head (lib.splitString " " identity.name))
        ]
        (builtins.readFile ./CLAUDE.md);
      slackMcp = machine.traits.profile == "work";
      slackTokens = [ "slack/user-token" "slack/xoxc-token" "slack/xoxd-token" ];
    in
    {
      dotfiles.credentials = lib.mkIf slackMcp {
        "slack/user-token" = {
          description = "Slack user token (xoxp-) for slack-mcp-server. Without it, slack/xoxc-token and slack/xoxd-token together do.";
          to = "slack-mcp";
          deliver.env = "SLACK_MCP_XOXP_TOKEN";
        };
        "slack/xoxc-token" = {
          description = "Slack browser token (xoxc-) that slack-mcp uses with slack/xoxd-token when there is no user token.";
          to = "slack-mcp";
          deliver.env = "SLACK_MCP_XOXC_TOKEN";
        };
        "slack/xoxd-token" = {
          description = "Slack browser cookie (xoxd-) that slack-mcp uses with slack/xoxc-token when there is no user token.";
          to = "slack-mcp";
          deliver.env = "SLACK_MCP_XOXD_TOKEN";
        };
      };

      dotfiles.fragments."claude/CLAUDE.md/private" = lib.mkIf (machine.private ? claudeMd) machine.private.claudeMd;

      dotfiles.mutable.".claude/settings.json" = {
        strategy = "merge-json";
        mode = "0600";
        json = {
          "$schema" = "https://json.schemastore.org/claude-code-settings.json";
          advisorModel = "fable";
          fallbackModel = [ "sonnet" ];
          effortLevel = "medium";
          fastModePerSessionOptIn = true;
          autoUpdatesChannel = "latest";
          cleanupPeriodDays = 365;
          feedbackSurveyRate = 0;
          attribution = { commit = ""; pr = ""; };
          extraKnownMarketplaces.cursor-plugins.source = { source = "github"; repo = "cursor/plugins"; };
          enabledPlugins."pstack@cursor-plugins" = true;
          env = {
            BASH_MAX_OUTPUT_LENGTH = "30000";
            MAX_MCP_OUTPUT_TOKENS = "25000";
          };
        };
      };

      dotfiles.mutable.".claude/keybindings.json" = { strategy = "seed"; source = ./keybindings.json; };

      programs.git.ignores = lib.mkIf (lib.elem "git" machine.enabled) [ "**/.claude/settings.local.json" ];

      home.file = {
        ".claude/CLAUDE.md".text = claudeMd;
        ".claude/references/mermaid-pdf.md".source = ./references/mermaid-pdf.md;
        ".bashrc.d/claude.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./claude.bashrc; };
        "scripts/undercover-hook" = { source = ./undercover-hook; executable = true; };
        "scripts/undercover-pr-hook" = { source = ./undercover-pr-hook; executable = true; };
        ".local/bin/slack-mcp" = lib.mkIf slackMcp {
          source = pkgs.writeShellScript "slack-mcp" ''exec ${config.dotfiles.withCredentials slackTokens} ${pkgs.runtimeShell} ${./slack-mcp} "$@"'';
          executable = true;
        };
      };

      home.activation.claudeCode = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -v DRY_RUN ]]; then
          ${install { inherit pkgs; home = config.home.homeDirectory; profile = config.home.profileDirectory; }}
        fi
      '';
    };

  checks = { pkgs, ... }:
    let
      curl = pkgs.writeShellScriptBin "curl" ''
        n=$(cat "$FAKE/fetches" 2>/dev/null || echo 0); echo $((n + 1)) > "$FAKE/fetches"
        while [ $# -gt 0 ]; do [ "$1" = -o ] && dest=$2; shift; done
        case $(cat "$FAKE/answer" 2>/dev/null) in
          offline) echo "curl: (6) Could not resolve host: claude.ai" >&2; exit 6 ;;
          portal) printf '%s\n' 'Sign in to the guest network' 'touch "$FAKE/ran"' > "$dest" ;;
          hang) exec sleep 60 > /dev/null 2>&1 ;;
          *) printf '%s\n' '#!/bin/sh' 'stat -c %a "$(dirname "$0")" > "$FAKE/dir-mode"' 'mkdir -p "$HOME/.local/bin"' 'printf "#!/bin/sh\necho claude\n" > "$HOME/.local/bin/claude"' 'chmod +x "$HOME/.local/bin/claude"' > "$dest" ;;
        esac
      '';
      stepFile = pkgs.writeText "claude-install-step" (install { pkgs = pkgs // { inherit curl; }; home = "$HOME"; profile = "$HOME/profile"; limit = 3; });
    in
    {
    claude-code-install = pkgs.runCommand "claude-code-install" { } ''
      export HOME=$TMPDIR/home FAKE=$TMPDIR/fake
      mkdir -p "$HOME" "$FAKE" "$FAKE/elsewhere"
      step() { PATH=$PATH:$FAKE/elsewhere ${pkgs.runtimeShell} -eu ${stepFile} 2>&1; }
      failures=0
      fail() { echo "FAIL $1"; echo "$said"; failures=$((failures + 1)); }
      fetches() { cat "$FAKE/fetches" 2>/dev/null || echo 0; }
      fresh() { rm -rf "$HOME/.local" "$HOME/profile" "$FAKE/fetches" "$FAKE/answer" "$FAKE/ran" "$FAKE/elsewhere/claude"; [ -z "''${1:-}" ] || echo "$1" > "$FAKE/answer"; }
      leftovers() { find "$TMPDIR" -maxdepth 1 -name 'claude-install.*' | wc -l; }

      said=$(step) || fail "the step succeeds when the installer works"
      [ -x "$HOME/.local/bin/claude" ] || fail "a missing claude is installed"
      [ "$(fetches)" = 1 ] || fail "the installer is fetched once"
      [ "$(cat "$FAKE/dir-mode" 2>/dev/null)" = 700 ] || fail "the installer is downloaded into a directory only the user can read"
      [ "$(leftovers)" = 0 ] || fail "the download is removed after it ran"
      said=$(step) || fail "the step succeeds when claude is there"
      [ "$(fetches)" = 1 ] || fail "a claude that is there is left to update itself, and nothing is fetched"

      fresh
      mkdir -p "$HOME/profile/bin"
      printf '#!/bin/sh\n' > "$HOME/profile/bin/claude"
      chmod +x "$HOME/profile/bin/claude"
      said=$(step) || fail "the step succeeds when the profile has claude"
      [ "$(fetches)" = 0 ] || fail "a claude in the profile is found, and nothing is fetched"

      fresh
      printf '#!/bin/sh\n' > "$FAKE/elsewhere/claude"
      chmod +x "$FAKE/elsewhere/claude"
      said=$(step) || fail "the step succeeds when claude is on the PATH"
      [ "$(fetches)" = 0 ] || fail "a claude anywhere on the PATH is found, and nothing is fetched"

      fresh offline
      said=$(step) || fail "a failed install does not fail the switch"
      case $said in *"installing Claude Code failed"*"curl -fsSL https://claude.ai/install.sh | bash"*) ;; *) fail "a failed install says what to run" ;; esac
      [ ! -e "$HOME/.local/bin/claude" ] || fail "a failed install leaves no claude"

      fresh portal
      said=$(step) || fail "a download that is not a script does not fail the switch"
      [ ! -e "$FAKE/ran" ] || fail "a download that does not start with a shebang line is never run"
      case $said in *"not a script"*"Run: curl -fsSL https://claude.ai/install.sh | bash"*) ;; *) fail "a download that is not a script says so and what to run" ;; esac
      [ "$(leftovers)" = 0 ] || fail "a download that was refused is removed"

      fresh hang
      SECONDS=0
      said=$(step) || fail "an install that hangs does not fail the switch"
      [ "$SECONDS" -lt 30 ] || fail "an install that hangs is cut off by the time limit, not waited for ($SECONDS s)"
      case $said in *"took over 3s"*) ;; *) fail "an install that hangs says what to run" ;; esac
      [ "$(leftovers)" = 0 ] || fail "the download of an install that hung is removed"

      [ "$failures" = 0 ]
      touch $out
    '';
  };

  inventory = {
    files = [
      ".claude/CLAUDE.md"
      ".claude/keybindings.json"
      ".claude/settings.json"
      ".claude/references/mermaid-pdf.md"
      ".bashrc.d/claude.bashrc"
      ".config/git/ignore"
      "scripts/undercover-hook"
      "scripts/undercover-pr-hook"
      ".local/bin/slack-mcp"
    ];
  };
}
