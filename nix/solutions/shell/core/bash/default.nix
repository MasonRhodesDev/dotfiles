{
  name = "bash";
  description = "Login shell, rc files, PATH helpers, history and shell options, completions.";
  platforms = [ "linux" "darwin" ];

  fragments = [ "bash/completions" ];

  home = { config, ... }: {
    home.file = {
      ".bashrc".source = ./bashrc;
      ".bash_profile".source = ./bash_profile;
      ".profile".source = ./profile;
      ".inputrc".source = ./inputrc;
      ".bashrc.d/00-path-helpers.bashrc".source = ./bashrc.d/00-path-helpers.bashrc;
      ".bashrc.d/01-history.bashrc".source = ./bashrc.d/01-history.bashrc;
      ".bashrc.d/02-shell-options.bashrc".source = ./bashrc.d/02-shell-options.bashrc;
      ".bashrc.d/scripts.bashrc".source = ./bashrc.d/scripts.bashrc;
      ".local/bin/refresh-completions" = {
        text = builtins.readFile ./refresh-completions + (config.dotfiles.fragments."bash/completions" or "");
        executable = true;
      };
    };
  };

  linux.root = { lib, machine, ... }: {
    packages = {
      arch = [ "bash-completion" ];
      fedora = [ "bash-completion" ];
    };
    script = ''
      if [ "$(getent passwd ${lib.escapeShellArg machine.user.name} | cut -d: -f7)" != /bin/bash ]; then
        usermod -s /bin/bash ${lib.escapeShellArg machine.user.name}
      fi
    '';
  };

  darwin.system = { pkgs, ... }: {
    environment.shells = [ pkgs.bashInteractive ];
    programs.bash.completion.enable = true;
  };

  checks = { pkgs, ... }: {
    bash-startup = pkgs.runCommand "bash-startup" { nativeBuildInputs = [ pkgs.bashInteractive ]; } ''
      export HOME=$PWD/home
      mkdir -p "$HOME/.bashrc.d" "$HOME/.local/bin" "$HOME/bin" "$HOME/scripts"
      cp ${./bashrc} "$HOME/.bashrc"
      cp ${./bash_profile} "$HOME/.bash_profile"
      cp ${./profile} "$HOME/.profile"
      cp ${./bashrc.d}/* "$HOME/.bashrc.d/"
      echo 'path_prepend "$HOME/bin"; PATH="$HOME/.local/bin:$PATH"' > "$HOME/.bashrc.d/zz-repeat.bashrc"

      result=$(bash --login -i -c 'echo "PATH=$PATH"; shopt -q globstar && echo globstar' 2> stderr)
      if grep -v -e 'no job control' -e 'terminal process group' stderr; then
        echo "a login shell wrote the lines above to stderr"
        exit 1
      fi
      path=$(sed -n 's/^PATH=//p' <<< "$result")
      if [ -n "$(tr : '\n' <<< "$path" | sort | uniq -d)" ]; then
        echo "PATH has duplicates: $path"
        exit 1
      fi
      case $path in
        "$HOME/.local/bin:"*) ;;
        *) echo "~/.local/bin is not first: $path"; exit 1 ;;
      esac
      grep -qx globstar <<< "$result" || { echo "globstar is off"; exit 1; }
      echo "$path" > $out
    '';
  };

  inventory = {
    files = [
      ".bashrc"
      ".bash_profile"
      ".profile"
      ".inputrc"
      ".bashrc.d/00-path-helpers.bashrc"
      ".bashrc.d/01-history.bashrc"
      ".bashrc.d/02-shell-options.bashrc"
      ".bashrc.d/scripts.bashrc"
      ".local/bin/refresh-completions"
      "nix:environment.shells"
    ];
    scripts = [
      {
        id = "03-ensure-bash-shell";
        root = true;
        note = "usermod on Linux; chsh by hand on darwin";
      }
      {
        id = "06-install-shell-tools:bash-completion";
        root = true;
      }
    ];
    packages = {
      linux = [ "bash-completion" ];
      darwin = [ "bash (5.x, replaces macOS bash 3.2)" ];
    };
  };
}
