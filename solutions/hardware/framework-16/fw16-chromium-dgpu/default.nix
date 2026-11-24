let
  blockFor = pkgs: dgpuPci: pkgs.writeText "chromium-local" ''
    # >>> dotfiles: chromium-local >>>
    DGPU_RENDER_NODE="$(readlink -f /dev/dri/by-path/pci-${dgpuPci}-render 2>/dev/null)"
    GPU_SELECT="$(cat "$HOME/.config/hypr/gpu-select" 2>/dev/null)"
    if [ -n "$DGPU_RENDER_NODE" ] && [ -e "$DGPU_RENDER_NODE" ] && [ "$GPU_SELECT" != "off" ]; then
       CHROMIUM_FLAGS+=" --render-node-override=$DGPU_RENDER_NODE"
    fi

    if ! pgrep -x chromium-browse >/dev/null 2>&1; then
       python3 - <<'PYEOF' 2>/dev/null
    import json, os
    p = os.path.expanduser("~/.config/chromium/Local State")
    try:
        with open(p) as f:
            d = json.load(f)
        if d.get("variations_crash_streak"):
            d["variations_crash_streak"] = 0
            with open(p, "w") as f:
                json.dump(d, f, separators=(",", ":"))
    except Exception:
        pass
    PYEOF
    fi
    # <<< dotfiles: chromium-local <<<
  '';

  step = { pkgs, dgpuPci, root ? "" }:
    let block = blockFor pkgs dgpuPci; in
    {
      distros = [ "fedora" ];
      script = ''
        conf=${root}/etc/chromium/chromium.conf
        begin='# >>> dotfiles: chromium-local >>>'
        end='# <<< dotfiles: chromium-local <<<'

        if [ ! -f "$conf" ]; then
            echo "$conf not present (chromium not installed?), skipping"
            exit 0
        fi

        current=$(sed -n "\|^$begin\$|,\|^$end\$|p" "$conf")
        if [ "$current" = "$(cat ${block})" ]; then
            exit 0
        fi

        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        if ! awk -v begin="$begin" -v end="$end" '
            open { if ($0 == end) open = 0; next }
            $0 == begin { open = 1; next }
            { print }
            END { if (open) { print begin; exit 1 } }
        ' "$conf" > "$tmp"; then
            echo "$conf has the marker $(tail -n 1 "$tmp") with no closing marker after it. Fix the file by hand; nothing was changed." >&2
            exit 1
        fi
        printf '\n%s\n' "$(cat ${block})" >> "$tmp"
        bash -n "$tmp"
        keep-original "$conf"
        cat "$tmp" > "$conf"
        echo "$conf: chromium-local block written, used from the next browser launch"
      '';
    };
in
{
  name = "FW16 browser dGPU pin";
  description = "Render-node pin for Chromium inside the Fedora-owned /etc/chromium/chromium.conf.";
  platforms = [ "linux" ];
  requires = [ "browsers" ];

  linux.root = { lib, machine, pkgs, ... }: lib.optionalAttrs (machine.private ? dgpuPci)
    (step { inherit pkgs; inherit (machine.private) dgpuPci; });

  checks = { pkgs, keepOriginal, ... }:
    let
      dgpuPci = "0000:ff:00.0";
      block = blockFor pkgs dgpuPci;
      script = pkgs.writeText "fw16-chromium-step" (step { inherit pkgs dgpuPci; root = "$ROOT"; }).script;
    in
    {
      fw16-chromium-conf = pkgs.runCommand "fw16-chromium-conf" { } ''
        export ROOT=$TMPDIR/root DOTFILES_STATE=$TMPDIR/root/var/lib/dotfiles PATH=${keepOriginal}/bin:$PATH
        conf=$ROOT/etc/chromium/chromium.conf
        mkdir -p "$(dirname "$conf")" "$DOTFILES_STATE"
        begin='# >>> dotfiles: chromium-local >>>'
        end='# <<< dotfiles: chromium-local <<<'
        step() { ${pkgs.runtimeShell} -euo pipefail ${script} 2>&1; }
        write() { printf '%s\n' "$@" > "$conf"; }
        failures=0
        fail() { echo "FAIL $1"; cat "$conf"; failures=$((failures + 1)); }
        written() { [ "$(cat "$conf")" = "$(printf '%s\n' "$@" ""; cat ${block})" ]; }
        refused() {
          local what=$1 before
          before=$(cat "$conf")
          if said=$(step); then fail "$what: the step fails"; fi
          [ "$(cat "$conf")" = "$before" ] || fail "$what: the file is left as it was"
          [ ! -e "$conf.pre-nix" ] || fail "$what: a file that is not edited gets no copy"
          case $said in *"Fix the file by hand"*) ;; *) fail "$what: the owner is told to fix the file" ;; esac
        }

        write 'BEFORE=1' 'AFTER=1'
        original=$(cat "$conf")
        step > /dev/null || fail "a file with no block: the step succeeds"
        written 'BEFORE=1' 'AFTER=1' || fail "a file with no block gets the block after its lines"
        [ "$(cat "$conf.pre-nix" 2>&1)" = "$original" ] || fail "the file as it was is kept beside the edited one"

        before=$(cat "$conf")
        said=$(step) || fail "a well-formed new block: the step succeeds"
        [ "$(cat "$conf")" = "$before" ] && [ -z "$said" ] || fail "a well-formed new block that is current is left alone"

        write 'BEFORE=1' "$begin" 'STALE=1' "$end" 'AFTER=1'
        step > /dev/null || fail "a well-formed new block with old content: the step succeeds"
        written 'BEFORE=1' 'AFTER=1' || fail "a well-formed new block with old content is replaced, and the lines around it stay"
        [ "$(cat "$conf.pre-nix")" = "$original" ] || fail "a later edit does not replace the copy"
        rm "$conf.pre-nix"

        write 'BEFORE=1' "$begin" 'STALE=1' 'AFTER=1'
        refused "an unclosed begin marker"
        write 'BEFORE=1' "$end" "$begin" 'STALE=1' 'AFTER=1'
        refused "an end marker before an unclosed begin marker"
        write "$begin" 'STALE=1' "$end" 'MIDDLE=1' "$begin" 'AFTER=1'
        refused "a closed block followed by an unclosed begin marker"

        rm "$conf"
        step > /dev/null || fail "no chromium.conf: the step succeeds"
        [ ! -e "$conf" ] || fail "no chromium.conf: none is created"

        [ "$failures" = 0 ]
        touch $out
      '';
    };
}
