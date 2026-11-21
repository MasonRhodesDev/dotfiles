{
  name = "CLI toolbelt";
  description = "curl, jq, unzip, gawk, btop, gh, rsync, fd, ripgrep, uv, kitty's terminfo in ~/.terminfo so SSH sessions from kitty work, and the global ripgrep/fd ignore file. GNU coreutils on darwin.";
  platforms = [ "linux" "darwin" ];

  home = { lib, pkgs, machine, ... }: {
    home.packages = with pkgs; [ curl jq unzip gawk btop gh rsync fd ripgrep uv ];
    dotfiles.credentials."github/cli" = {
      description = "gh's own GitHub login, which also derives the npm packages token.";
      to = "gh";
      deliver.login = "gh auth login";
      probe = "gh auth status --hostname github.com";
    };
    home.file.".ignore".source = ./ignore;
    home.file.".terminfo" = { source = "${pkgs.kitty.terminfo}/share/terminfo"; recursive = true; };
    dotfiles.fragments."bash/completions" = lib.mkIf (lib.elem "bash" machine.enabled) "gen uv        uv generate-shell-completion bash\ngen uvx       uvx --generate-shell-completion bash\n";
  };

  darwin.home = { pkgs, ... }: {
    home.packages = [ pkgs.coreutils ];
  };

  inventory = {
    files = [ ".ignore" ".terminfo/**" ".local/bin/refresh-completions#uv" ];
    packages = {
      linux = [ "curl" "jq" "unzip" "gawk" "btop" "gh" "rsync" "fd" "ripgrep" "uv" "kitty-terminfo" "paru" "downgrade" ];
      darwin = [ "curl" "jq" "unzip" "gawk" "btop" "gh" "rsync" "fd" "ripgrep" "uv" "kitty-terminfo" "coreutils" ];
    };
  };
}
