{ lib, pkgs, stub, evalHome }:
let
  tool = config: "${config.dotfiles.credential}/bin/dotfiles-credential";
  vault = store: (evalHome {
    modules = [
      (import ../solutions/secrets/runtime/vault-provider.nix).home
      {
        dotfiles.credentialStore = store;
        dotfiles.credentials."fixture/token" = { description = "A fixture token with a derive."; deliver.env = "FIXTURE_TOKEN"; derive = "gh auth token"; };
      }
    ];
  }).config;

  infisical = tool stub.stub-work-laptop.configuration.config;
  bitwarden = tool stub.stub-bitwarden-server.configuration.config;
  none = tool stub.stub-headless.configuration.config;
  rbwVault = tool (vault "secret-service");
  keychainVault = tool (vault "keychain");
  vaultPackages = map lib.getName (vault "secret-service").home.packages;
  secretsProject = stub.stub-bitwarden-server.private.bitwarden.secretsProject;
in
pkgs.runCommand "check-credential-chain" { } ''
  set -u
  sentinel=SENTINEL-c4a1-9e11
  token=0.00000000-0000-4000-8000-00000000f1f1.fixtureClientSecret0123:Zml4dHVyZS1lbmNyeXB0aW9uLWtleQ==
  fakes=$TMPDIR/fakes
  fake=$TMPDIR/fake
  log=$TMPDIR/log
  scratch=$TMPDIR/home
  mkdir -p "$fakes/all" "$fakes/no-vault"

  cat > "$fakes/all/secret-tool" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "secret-tool $*" >> "$LOG/argv"
  [ ! -e "$FAKE/keyring-locked" ] || { echo "Cannot unlock the login collection" >&2; exit 1; }
  case $1 in
    lookup) grep -qxF -- "$5" "$FAKE/keyring" 2>/dev/null && printf 'keyring-%s' "$SENTINEL" ;;
    store) cat > "$FAKE/keyring-stored" ;;
    *) exit 1 ;;
  esac
  EOF
  cat > "$fakes/all/security" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "security $*" >> "$LOG/argv"
  [ ! -e "$FAKE/keychain-locked" ] || { echo "security: SecKeychainSearchCopyNext: User interaction is not allowed." >&2; exit 36; }
  case $1 in
    find-generic-password)
      [ "$2 $3 $4" = "-s dotfiles -a" ] && [ "$6" = -w ] || exit 2
      grep -qxF -- "$5" "$FAKE/keychain" 2>/dev/null || { echo "security: The specified item could not be found in the keychain." >&2; exit 44; }
      printf 'keychain-%s\n' "$SENTINEL" ;;
    -i) cat > "$FAKE/keychain-commands" ;;
    *) exit 2 ;;
  esac
  EOF
  cat > "$fakes/all/infisical" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "infisical $*" >> "$LOG/argv"
  case $1 in
    login) [ "''${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET-}" = "client-$SENTINEL" ] && echo "itoken-$SENTINEL" ;;
    export)
      [ "''${INFISICAL_TOKEN-}" = "itoken-$SENTINEL" ] && [ ! -e "$FAKE/infisical-down" ] || exit 1
      case " $* " in
        *" --path /github "*) [ -e "$FAKE/infisical-held" ] && printf '[{"key": "PACKAGES_TOKEN", "value": "infisical-%s"}]\n' "$SENTINEL" || echo '[]' ;;
        *) echo '[]' ;;
      esac ;;
    *) exit 1 ;;
  esac
  EOF
  cat > "$fakes/all/bws" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "bws $*" >> "$LOG/argv"
  [ "''${BWS_ACCESS_TOKEN-}" = "$TOKEN" ] && [ ! -e "$FAKE/bws-down" ] || { echo "Error: error sending request" >&2; exit 1; }
  if [ -e "$FAKE/bws-held" ]; then printf '[{"key": "tailscale/work/authkey", "value": "bws-%s"}]\n' "$SENTINEL"; else echo '[]'; fi
  EOF
  cat > "$fakes/all/rbw" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "rbw $*" >> "$LOG/argv"
  case $1 in
    unlocked) [ -e "$FAKE/rbw-unlocked" ] ;;
    get) [ -e "$FAKE/rbw-unlocked" ] && [ "$2" = -- ] && grep -qxF -- "$3" "$FAKE/rbw-items" 2>/dev/null && printf 'rbw-%s\n' "$SENTINEL" ;;
    *) exit 1 ;;
  esac
  EOF
  cat > "$fakes/all/bw" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "bw $*" >> "$LOG/argv"
  unlocked() { [ -e "$FAKE/bw-unlocked" ] && [ "''${BW_SESSION-}" = "session-$SENTINEL" ]; }
  case $1 in
    status) if unlocked; then echo '{"status": "unlocked"}'; else echo '{"status": "locked"}'; fi ;;
    get) unlocked && [ "$2" = password ] && grep -qxF -- "$3" "$FAKE/bw-items" 2>/dev/null && printf 'bw-%s' "$SENTINEL" ;;
    *) exit 1 ;;
  esac
  EOF
  cat > "$fakes/all/gh" <<'EOF'
  #!${pkgs.runtimeShell}
  printf '%s\n' "gh $*" >> "$LOG/argv"
  [ -e "$FAKE/gh-login" ] && [ "$*" = "auth token" ] && printf 'derived-%s\n' "$SENTINEL"
  EOF
  chmod +x "$fakes/all"/*
  for f in secret-tool security infisical bws gh; do ln -s "$fakes/all/$f" "$fakes/no-vault/$f"; done

  failures=0
  fail() { echo "FAIL $1"; printf '%s\n' "$err" | sed 's/^/  said: /'; sed 's/^/  call: /' "$log/argv" 2>/dev/null || true; failures=$((failures + 1)); }

  home() {
    chmod -R u+w "$scratch" "$fake" 2>/dev/null || true
    rm -rf "$scratch" "$fake"
    mkdir -p "$scratch/.config/infisical" "$scratch/.config/bitwarden" "$fake"
    printf '%s\n' INFISICAL_CLIENT_ID=fixture-id "INFISICAL_CLIENT_SECRET=client-$sentinel" > "$scratch/.config/infisical/machine.env"
    printf 'BWS_ACCESS_TOKEN=%s\n' "$token" > "$scratch/.config/bitwarden/machine.env"
    for flag in "$@"; do
      case $flag in
        keyring=* | keychain=* | rbw-items=* | bw-items=*) printf '%s\n' "''${flag#*=}" >> "$fake/''${flag%%=*}" ;;
        stored=*)
          mkdir -p "$(dirname "$scratch/.local/state/dotfiles/credentials/''${flag#stored=}")"
          printf 'file-%s\n' "$sentinel" > "$scratch/.local/state/dotfiles/credentials/''${flag#stored=}"
          chmod 600 "$scratch/.local/state/dotfiles/credentials/''${flag#stored=}" ;;
        *) touch "$fake/$flag" ;;
      esac
    done
  }

  leaks() {
    local f
    case "$out_seen$err" in *"$sentinel"*) fail "$1: no value reaches stdout or stderr" ;; esac
    if grep -qF "$sentinel" "$log/argv" 2>/dev/null; then fail "$1: no value is on a command line"; fi
    while IFS= read -r f; do
      case $f in
        "$fake"/* | "$scratch/.config/infisical/machine.env") ;;
        "$scratch/.local/state/dotfiles/credentials/"*) [ "$(stat -c %a "$f")" = 600 ] || fail "$1: $f holds a value and is not 0600" ;;
        *) fail "$1: no value is left in $f" ;;
      esac
    done < <(grep -rlF "$sentinel" "$TMPDIR" --exclude-dir=fakes 2>/dev/null | grep -v -e "^$log/" -e "^$TMPDIR/env-vars$" -e "^$TMPDIR/.attr")
  }

  get() {
    local bin=$1 path=$2; shift 2
    rm -rf "$log" && mkdir -p "$log"
    value=$(cd "$scratch" && env -i HOME="$scratch" LOG="$log" FAKE="$fake" SENTINEL="$sentinel" TOKEN="$token" ''${SESSION:+BW_SESSION=$SESSION} \
      PATH="$fakes/$path:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin" "$bin" get "$@" 2> "$log/stderr"; code=$?; printf x; exit $code) && status=0 || status=$?
    value=''${value%x}
    err=$(cat "$log/stderr")
    out_seen=
    leaks "$*"
  }
  answered() {
    [ "$status" = 0 ] || fail "$2: get exits 0, not $status"
    [ "$value" = "$1-$sentinel" ] || fail "$2: the $1 tier answers"
  }
  asked() { grep -q "^$1" "$log/argv" 2>/dev/null || fail "$2: $1 is asked"; }
  skipped() { ! grep -q "^$1" "$log/argv" 2>/dev/null || fail "$2: $1 is never asked"; }
  manual() {
    [ "$status" = 3 ] || fail "$1: with no tier holding it, get exits 3, not $status"
    [ -z "$value" ] || fail "$1: with no tier holding it, nothing is on stdout"
    local title=$1; shift
    for said in "$@"; do case $err in *"$said"*) ;; *) fail "$title: the manual step says '$said'" ;; esac; done
  }

  SESSION=
  home keyring=github/packages-token infisical-held gh-login
  get ${infisical} no-vault github/packages-token
  answered keyring "Secret Service first"
  skipped infisical "Secret Service first"
  skipped gh "Secret Service first"

  home keyring=github/packages-token keyring-locked infisical-held gh-login
  get ${infisical} no-vault github/packages-token
  answered infisical "a locked keyring falls through to the provider"

  home infisical-held gh-login
  get ${infisical} no-vault github/packages-token
  answered infisical "no keyring item falls through to Infisical"
  skipped gh "the provider answers before derive"

  home infisical-down gh-login
  get ${infisical} no-vault github/packages-token
  answered derived "an unreachable Infisical falls through to derive"

  home
  get ${infisical} no-vault github/packages-token
  manual "nothing anywhere" "local store: no keyring item service=dotfiles account=github/packages-token" "provider: Infisical has no PACKAGES_TOKEN in /github" "derive: gh auth token gave nothing" "run: dotfiles-credential set github/packages-token"

  home stored=tailscale/work/authkey bws-held
  get ${bitwarden} no-vault tailscale/work/authkey
  answered file "the headless file store first"
  skipped bws "the headless file store first"

  home stored=tailscale/work/authkey bws-held
  echo readable-by-others > "$scratch/.local/state/dotfiles/credentials/tailscale/work/authkey"
  chmod 644 "$scratch/.local/state/dotfiles/credentials/tailscale/work/authkey"
  get ${bitwarden} no-vault tailscale/work/authkey
  answered bws "a stored file others can read is refused, and Bitwarden Secrets Manager answers"

  home bws-held
  get ${bitwarden} no-vault tailscale/work/authkey
  answered bws "no stored file falls through to Bitwarden Secrets Manager"
  grep -q "^bws secret list ${secretsProject} " "$log/argv" || fail "Bitwarden Secrets Manager is asked for the machine's secrets project"

  home bws-down
  get ${bitwarden} no-vault tailscale/work/authkey
  manual "Bitwarden offline and no derive" "local store: no file ~/.local/state/dotfiles/credentials/tailscale/work/authkey" "provider: could not list the Bitwarden project" "run: dotfiles-credential set tailscale/work/authkey"

  home rbw-unlocked rbw-items=fixture/token bw-unlocked bw-items=fixture/token gh-login
  SESSION=session-$sentinel
  get ${rbwVault} all fixture/token
  answered rbw "an unlocked rbw answers"
  skipped bw "an unlocked rbw answers before bw"

  home bw-unlocked bw-items=fixture/token gh-login
  get ${rbwVault} all fixture/token
  answered bw "a locked rbw falls through to an unlocked bw"

  home rbw-unlocked bw-unlocked bw-items=fixture/token gh-login
  get ${rbwVault} all fixture/token
  answered derived "an unlocked rbw without the item does not fall back to bw, and derive answers"

  home bw-items=fixture/token gh-login
  SESSION=
  get ${rbwVault} all fixture/token
  answered derived "bw without BW_SESSION counts as locked, and derive answers"
  case $err in "") ;; *) fail "a locked vault that derive covers says nothing" ;; esac

  home
  get ${rbwVault} all fixture/token
  manual "a locked vault and no gh login" "provider: the vault is locked (run rbw unlock, or bw unlock and export BW_SESSION)" "derive: gh auth token gave nothing"

  home
  get ${rbwVault} no-vault fixture/token
  manual "no vault CLI" "provider: neither rbw nor bw is installed"

  home keychain=fixture/token rbw-unlocked rbw-items=fixture/token
  get ${keychainVault} all fixture/token
  answered keychain "the login Keychain first, its trailing newline dropped"
  skipped rbw "the login Keychain first"

  home keychain=fixture/token keychain-locked rbw-unlocked rbw-items=fixture/token
  get ${keychainVault} all fixture/token
  answered rbw "a Keychain locked over ssh falls through to the vault"

  home rbw-unlocked rbw-items=fixture/token
  get ${keychainVault} all fixture/token
  answered rbw "no Keychain item falls through to the vault"

  home
  rm -rf "$log" && mkdir -p "$log"
  printf 'keychain-%s\n' "$sentinel" | env -i HOME="$scratch" LOG="$log" FAKE="$fake" SENTINEL="$sentinel" PATH="$fakes/all:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin" ${keychainVault} set fixture/token 2> "$log/stderr" && status=0 || status=$?
  err=$(cat "$log/stderr"); out_seen=
  [ "$status" = 0 ] || fail "set into the Keychain exits 0, not $status"
  [ "$(cat "$fake/keychain-commands" 2>/dev/null)" = "add-generic-password -U -s dotfiles -a \"fixture/token\" -w \"keychain-$sentinel\"" ] || fail "set hands the Keychain its command on stdin"
  leaks "set into the Keychain"
  printf 'a"quote-%s\n' "$sentinel" | env -i HOME="$scratch" LOG="$log" FAKE="$fake" SENTINEL="$sentinel" PATH="$fakes/all:${pkgs.coreutils}/bin" ${keychainVault} set fixture/token 2> "$log/stderr" && status=0 || status=$?
  err=$(cat "$log/stderr")
  [ "$status" = 3 ] || fail "a value the Keychain command cannot carry is refused, not exit $status"
  leaks "a refused Keychain value"

  home stored=tailscale/personal/authkey
  get ${none} no-vault tailscale/personal/authkey
  answered file "secrets = none still has the local store"

  home
  get ${none} no-vault tailscale/personal/authkey
  manual "secrets = none" "provider: this machine has no secrets provider" "run: dotfiles-credential set tailscale/personal/authkey"

  for wanted in rbw bitwarden-cli; do
    case " ${toString vaultPackages} " in *" $wanted "*) ;; *) err="${toString vaultPackages}"; fail "the vault provider installs $wanted" ;; esac
  done

  [ "$failures" = 0 ]
  touch $out
''
