[
  {
    item = "scripts/terminal-header/sections/summary.ts";
    reason = "The pane summarizer it showed is not used.";
  }
  {
    item = "scripts/terminal-header/test.ts";
    reason = "The resolver test runs in nix flake check (terminal-header-resolver), not from the home.";
  }
  {
    item = ".config/wezterm/headerModulesLoader.lua";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = ".config/systemd/user/pane-summarizer.service";
    reason = "The pane summarizer is not used.";
  }
  {
    item = "scripts/wezterm-pane-summarizer.ts";
    reason = "The pane summarizer is not used.";
  }
  {
    item = ".config/wezterm/headerModules/claude.lua";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = ".config/wezterm/headerModules/pane_summary.lua";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = ".config/wezterm/headerModules/ssh.lua";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = "scripts/test-wezterm-agent-status.ts";
    reason = "A test of the live terminal config, not a tool for the home.";
  }
  {
    item = ".config/systemd/user/ollama.service";
    reason = "Ollama is not used.";
  }
  {
    item = "pkg:ollama";
    reason = "Ollama is not used.";
  }
  {
    item = ".bashrc.d/kimi.bashrc";
    reason = "Kimi Code is not used.";
  }
  {
    item = ".config/systemd/user/claude-desktop-update.service";
    reason = "Claude Desktop is not used. The claude CLI is installed by claude-code.";
  }
  {
    item = ".config/systemd/user/claude-desktop-update.timer";
    reason = "Claude Desktop is not used. The claude CLI is installed by claude-code.";
  }
  {
    item = ".local/bin/claude-desktop-update";
    reason = "Claude Desktop is not used. The claude CLI is installed by claude-code.";
  }
  {
    item = "pkg:Claude Desktop";
    reason = "Claude Desktop is not used. The claude CLI is installed by claude-code.";
  }
  {
    item = "56-asahi-bcm4378-sleep";
    reason = "Asahi hardware is gone: that laptop runs macOS now.";
  }
  {
    item = "57-asahi-battery";
    reason = "Asahi hardware is gone: that laptop runs macOS now.";
  }
  {
    item = "58-asahi-fnkeys";
    reason = "Asahi hardware is gone: that laptop runs macOS now.";
  }
  {
    item = ".config/hypr/power.conf#lid-absent";
    reason = "chezmoi wrote `lid = absent` only on the Asahi laptop, to work around hyprstate's lid grace there. That laptop runs macOS now.";
  }
  {
    item = "01-install-jq";
    reason = "jq is a cli-toolbelt package.";
  }
  {
    item = "34-claude-cowork-vm";
    reason = "Ensure-absent cleanup that has already run.";
  }
  {
    item = "52-fw16-mt7922-wifi";
    reason = "Inert on kernel 6.19 and later. Remove wifi-resume.service and wifi-health-check.service from W once by hand if present.";
  }
  {
    item = "98-check-packages-with-claude";
    reason = "Declared package sets replace the audit.";
  }
  {
    item = "99-reset-drift-cache";
    reason = "Dies with chezmoi.";
  }
  {
    item = "99-track-system";
    reason = "Publishes hostnames. The private repo is the registry now.";
  }
  {
    item = "remove-root-wezterm-config";
    reason = "One-time cleanup.";
  }
  {
    item = "54-third-party-repos:slack";
    reason = "Slack's Fedora repository stays out: the key that signs its packages is published nowhere, so it cannot be pinned.";
  }
  {
    item = "enable-user-services";
    reason = "Replaced by the layer system. Its five units belong to keyring-session-env, browsers, keyring, infisical-sync and secret-inbox.";
  }
  {
    item = ".config/fish/**";
    reason = "fish retired 2026-08. Takes datadog.fish with it (q-fish).";
  }
  {
    item = ".config/zed/keymap.json";
    reason = "Content is [] and Zed rewrites it.";
  }
  {
    item = ".config/software-manifest.md";
    reason = "Describes one machine's hand-built software.";
  }
  {
    item = ".bashrc.d/environment.bashrc";
    reason = "One line, a dead WALLPAPER_PATH with a hardcoded home path.";
  }
  {
    item = ".bashrc.d/chezmoi-drift.bashrc";
    reason = "chezmoi tooling.";
  }
  {
    item = ".local/bin/chezmoi-refresh-identity";
    reason = "chezmoi tooling.";
  }
  {
    item = "scripts/chezmoi-package-check.py";
    reason = "chezmoi tooling.";
  }
  {
    item = ".claude/skills/chezmoi/SKILL.md";
    reason = "chezmoi tooling.";
  }
  {
    item = "source:dot_config/btop/btop.conf";
    reason = "Never deployed.";
  }
  {
    item = "source:dot_claude/templates/**";
    reason = "Never deployed.";
  }
  {
    item = "source:software_installers/";
    reason = "Verify-only checklist, installs nothing.";
  }
  {
    item = "pkg:fish";
    reason = "Goes with the config.";
  }
  {
    item = "pkg:wayfreeze";
    reason = "No config or bind runs it. hypr-DE's snip freezes the screen with hyprpicker.";
  }
  {
    item = "pkg:wayshot";
    reason = "No config or bind runs it. hypr-DE's snip and record use grim and slurp.";
  }
  {
    item = "pkg:bemoji";
    reason = "No config or bind runs it.";
  }
  {
    item = "pkg:olk";
    reason = "The owner does not want olk.";
  }
  {
    item = "pkg:mongodb";
    reason = "The server: chezmoi never installed it, neither distro ships it, and nixpkgs has it only unfree. mongosh stays.";
  }
  {
    item = ".local/share/notes/steam-overlay-fix.md";
    reason = "One machine's investigation log, naming that machine. Not configuration.";
  }
  {
    item = ".gitconfig-personal";
    reason = "Each includeIf identity is a store file that ~/.config/git/config includes (programs.git.includes), so the per-identity files are gone.";
  }
  {
    item = ".gitconfig-work";
    reason = "Each includeIf identity is a store file that ~/.config/git/config includes (programs.git.includes), so the per-identity files are gone.";
  }
  {
    item = ".config/systemd/user/herdr.service.d/50-skip-if-running.conf";
    reason = "Folded into herdr.service as its ExecCondition.";
  }
  {
    item = ".local/share/applications/drawio.desktop";
    reason = "draw.io is not used.";
  }
  {
    item = "nix-environments/playwright.nix";
    reason = "The Playwright devShell is not used.";
  }
  {
    item = ".bashrc.d/misc-functions.bashrc";
    reason = "Its one function enabled the Playwright devShell, which is not used.";
  }
  {
    item = ".config/systemd/user/thermal-tripwire.service";
    reason = "The thermal tripwire is not used.";
  }
  {
    item = "scripts/thermal-tripwire";
    reason = "The thermal tripwire is not used.";
  }
  {
    item = ".local/share/applications/clickup-icon.png";
    reason = "ClickUp is not used.";
  }
  {
    item = ".config/systemd/user/buzz-appimage-patch.path";
    reason = "Buzz is not used.";
  }
  {
    item = ".config/systemd/user/buzz-appimage-patch.service";
    reason = "Buzz is not used.";
  }
  {
    item = ".local/bin/buzz-appimage-patch";
    reason = "Buzz is not used.";
  }
  {
    item = ".local/bin/buzz-desktop";
    reason = "Buzz is not used.";
  }
  {
    item = ".local/bin/appimage-safe-open";
    reason = "Buzz, its only user, is not used.";
  }
  {
    item = ".local/share/applications/buzz.desktop";
    reason = "Buzz is not used.";
  }
  {
    item = ".config/environment.d/appimage-browser.conf";
    reason = "Buzz, its only user, is not used.";
  }
  {
    item = "scripts/cb";
    reason = "The cb remote build wrapper is not used.";
  }
  {
    item = ".local/bin/cb";
    reason = "The cb remote build wrapper is not used.";
  }
  {
    item = ".bashrc.d/cursor.bashrc";
    reason = "Cursor is not used.";
  }
  {
    item = ".config/wezterm/wezterm.lua";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = "scripts/terminal-header/targets/wezterm.ts";
    reason = "WezTerm is not used. kitty is the only terminal.";
  }
  {
    item = "scripts/wezterm-agent-bridge.ts";
    reason = "agent-pane-status ships it as scripts/agent-status-bridge.ts, for kitty only.";
  }
  {
    item = "scripts/wezterm-agent-runner.ts";
    reason = "agent-pane-status ships it as scripts/agent-status-runner.ts, for kitty only.";
  }
  {
    item = "scripts/codex-wezterm.ts";
    reason = "agent-pane-status ships it as scripts/agent-status-codex.ts, for kitty only.";
  }
  {
    item = "scripts/pi-wezterm.ts";
    reason = "agent-pane-status ships it as scripts/agent-status-pi.ts, for kitty only.";
  }
  {
    item = "scripts/wezterm-claude-activity-hook";
    reason = "agent-pane-status ships it as scripts/agent-status-claude-activity-hook, for kitty only.";
  }
  {
    item = "scripts/wezterm-claude-cleanup-hook";
    reason = "agent-pane-status ships it as scripts/agent-status-claude-cleanup-hook, for kitty only.";
  }
  {
    item = "scripts/wezterm-claude-session-hook";
    reason = "agent-pane-status ships it as scripts/agent-status-claude-session-hook, for kitty only.";
  }
  {
    item = "scripts/wezterm-claude-summarize";
    reason = "agent-pane-status ships it as scripts/agent-status-claude-summarize, for kitty only.";
  }
  {
    item = ".bashrc.d/wezterm-shims.bashrc";
    reason = "agent-pane-status ships it as .bashrc.d/agent-status.bashrc, for kitty only. Its claude-track helper was for WezTerm only.";
  }
  {
    item = ".config/hypr/.cursor/rules";
    reason = "Cursor editor rules, not part of the window manager.";
  }
  {
    item = ".bashrc.d/go.bashrc";
    reason = "Its only job was the GVM guard. Go comes from the flake.";
  }
  {
    item = "54-third-party-repos:vivaldi";
    reason = "Vivaldi is not used.";
  }
  {
    item = "54-third-party-repos:google-chrome";
    reason = "Linux uses Chromium only.";
  }
  {
    item = "pkg:google-chrome";
    reason = "Linux uses Chromium only.";
  }
  {
    item = ".bashrc.d/ydotool.bashrc";
    reason = "Voice dictation types with wtype, so nothing reads YDOTOOL_SOCKET.";
  }
]
