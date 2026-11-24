{
  lmtt = {
    why = "lmtt writes theme files through symlinks, so a store link fails with EROFS";
    fix = "Declare it with dotfiles.mutable, or leave it unmanaged.";
    paths = [
      "**/lmtt-*"
      ".tmux.conf"
      ".config/tmux/tmux.conf"
      ".config/kitty/kitty.conf"
      ".config/hypr/hyprtoolkit.conf"
      ".config/gtk-3.0/settings.ini"
      ".config/gtk-4.0/settings.ini"
      ".config/lmtt/config.toml"
    ];
  };

  shared-dir = {
    why = "lmtt, hyprstate, Claude Code, infisical-sync and installers add files to it at runtime, so it cannot be one read-only store link";
    fix = "Link the files inside it one by one (recursive = true), or declare them with dotfiles.mutable.";
    dirs = [
      ".config/hypr"
      ".config/kitty"
      ".config/tmux"
      ".config/lmtt"
      ".config/nvim"
      ".config/infisical"
      ".config/fish/conf.d"
      ".config/gtk-3.0"
      ".config/gtk-4.0"
      ".config/zed"
      ".claude"
      ".local/bin"
      ".local/share/applications"
    ];
  };

  app = {
    why = "the app rewrites its own config and replaces the link or fails to write";
    fix = "Declare it with dotfiles.mutable (merge-json when the app keeps keys of its own), or leave it unmanaged.";
    paths = [
      ".claude/settings.json"
      ".config/zed/settings.json"
      ".config/zed/keymap.json"
      ".config/mimeapps.list"
      ".config/nvim/lazy-lock.json"
      ".config/karabiner/karabiner.json"
    ];
  };

  runtime-secret = {
    why = "it holds secrets that infisical-sync fetches at runtime, and anything the flake declares lands world-readable in the store";
    fix = "Leave it unmanaged.";
    secret = true;
    paths = [
      ".config/infisical/*.env"
      ".config/infisical/env.sh"
      ".config/dotfiles/env.sh"
      ".local/state/dotfiles/credentials/*"
      ".local/state/dotfiles/credentials/*/*"
      ".local/state/dotfiles/credentials/*/*/*"
      ".config/secrets.env"
    ];
  };
}
