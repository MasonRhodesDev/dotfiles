{ lib, pkgs, machine, identity, ... }:
let
  publicKey = name: key:
    if builtins.match "[A-Za-z0-9._-]+:[A-Za-z0-9+/]{43}=" key != null then key
    else throw "identity.buildHosts.${name} is not a Nix public key in the form nix key convert-secret-to-public prints (name:base64)";
  keys = lib.mapAttrs publicKey (identity.buildHosts or { });
  signs = keys ? ${machine.name or ""};
  trusts = keys != { } && (signs || (machine.private.buildHost or null) != null);
  restart = "systemctl try-restart nix-daemon.service";
in
{
  config = lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && (trusts || signs)) {
    dotfiles.root.build-trust = {
      files."/etc/nix/dotfiles.conf" = {
        text = lib.optionalString trusts "extra-trusted-public-keys = ${toString (lib.attrValues keys)}\n"
          + lib.optionalString signs "!include dotfiles-signing.conf\n";
        reload = restart;
      };
      script = ''
        say() { echo "dotfiles-root-apply: $*" >&2; }
        dir=''${DOTFILES_ROOT_PREFIX:-}/etc/nix
        changed=
        reads=$dir/nix.conf
        if grep -qxF '!include nix.custom.conf' "$reads" 2>/dev/null; then reads=$dir/nix.custom.conf; fi
        if ! grep -qxF '!include dotfiles.conf' "$reads" 2>/dev/null; then
          if [ -s "$reads" ] && [ -n "$(tail -c 1 "$reads")" ]; then echo >> "$reads"; fi
          echo '!include dotfiles.conf' >> "$reads"
          echo "nix reads /etc/nix/dotfiles.conf from ''${reads#"''${DOTFILES_ROOT_PREFIX:-}"}"
          changed=1
        fi
      '' + lib.optionalString signs ''
        key=$dir/dotfiles-signing.sec
        signing=$dir/dotfiles-signing.conf
        problem=
        if [ ! -f "$key" ] || [ -L "$key" ]; then
          problem="/etc/nix/dotfiles-signing.sec is missing. The cleanup runbook's build host step B1 makes it"
        elif [ "$(stat -c '%a %u' "$key")" != "600 $(id -u)" ]; then
          problem="/etc/nix/dotfiles-signing.sec must be mode 0600 and owned by root. sudo chown root:root and sudo chmod 600 it, as the cleanup runbook's build host step B1 leaves it"
        else
          secret=$(cat "$key")
          derived=''${secret%%:*}:$(printf %s "''${secret#*:}" | base64 -d 2>/dev/null | tail -c 32 | base64 -w 0 || true)
          unset secret
          [ "$derived" = ${lib.escapeShellArg keys.${machine.name}} ] \
            || problem="/etc/nix/dotfiles-signing.sec is not the key whose public half identity.buildHosts.${machine.name} names. The cleanup runbook's build host step B2 puts its public half there"
        fi
        if [ -n "$problem" ]; then
          if [ -e "$signing" ]; then rm -f "$signing"; changed=1; fi
          [ -z "$changed" ] || ${restart}
          say "this machine is a build host in identity.buildHosts and signs nothing it builds: $problem. Once that is fixed, its step B4 signs what was built in between"
          exit 1
        fi
        if [ "$(cat "$signing" 2>/dev/null)" != "secret-key-files = $key" ]; then
          echo "secret-key-files = $key" > "$signing"
          echo "nix signs what it builds here with /etc/nix/dotfiles-signing.sec"
          changed=1
        fi
      '' + ''
        [ -z "$changed" ] || ${restart}
      '';
    };
  };
}
