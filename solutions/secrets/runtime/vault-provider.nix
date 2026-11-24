{
  name = "Bitwarden personal vault provider";
  description = "Reads a named credential from the owner's personal Bitwarden vault, through rbw or the official bw CLI, whichever is installed and unlocked; a locked or missing vault falls through to the next tier. The name tailscale/work/authkey is the vault item of that name, and its password field is the value. Installs both rbw and bw.";
  platforms = [ "linux" "darwin" ];
  when.secrets = "bitwarden-vault";

  home = { pkgs, ... }:
    let
      vault = ''
        jq=${pkgs.jq}/bin/jq
        rbw_ready() { command -v rbw >/dev/null 2>&1 && rbw unlocked >/dev/null 2>&1; }
        bw_ready() { command -v bw >/dev/null 2>&1 && [ "$(bw status --nointeraction 2>/dev/null | $jq -r '.status // empty' 2>/dev/null)" = unlocked ]; }
        from_vault() {
          local value
          if rbw_ready; then value=$(${pkgs.coreutils}/bin/timeout 30 rbw get -- "$1" 2>/dev/null) || value=
          elif bw_ready; then value=$(${pkgs.coreutils}/bin/timeout 30 bw get password "$1" --nointeraction 2>/dev/null) || value=
          else return 4
          fi
          [ -n "$value" ] || return 1
          printf '%s' "$value"
        }
        why_not() {
          if ! command -v rbw >/dev/null 2>&1 && ! command -v bw >/dev/null 2>&1; then echo "neither rbw nor bw is installed"
          else echo "the vault is locked (run rbw unlock, or bw unlock and export BW_SESSION)"
          fi
        }
      '';
    in
    {
      home.packages = [ pkgs.rbw pkgs.bitwarden-cli ];

      dotfiles.credentialProvider = {
        unconfigured = null;

        get = pkgs.writeShellScript "vault-credential" ''
          ${vault}
          from_vault "$1"
          case $? in
            0) ;;
            4) why_not >&2; exit 3 ;;
            *) echo "the vault has no item named $1 with a password" >&2; exit 3 ;;
          esac
        '';

        has = pkgs.writeShellScript "vault-presence" ''
          ${vault}
          rbw_ready || bw_ready || { why_not >&2; exit 3; }
          for name in "$@"; do
            if from_vault "$name" > /dev/null; then printf '%s\n' "$name"; fi
          done
        '';
      };
    };
}
