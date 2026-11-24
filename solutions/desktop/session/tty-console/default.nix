let
  unit = "dotfiles-console-font.service";
  program = "/usr/local/libexec/dotfiles-console-font";
in
{
  name = "TTY console";
  description = "Disaster-recovery VTs: cage+kitty on tty2, tmux on tty3+, gpm mouse, and a Terminus font that each boot sizes to the display the machine booted on, on every text console, without touching vconsole.conf or the initramfs.";
  platforms = [ "linux" ];

  linux.home = { lib, machine, ... }: {
    home.file.".bashrc.d/00-tty-console.bashrc" = lib.mkIf (lib.elem "bash" machine.enabled) { source = ./00-tty-console.bashrc; };
  };

  linux.root = {
    packages = {
      arch = [ "terminus-font" "kbd" "gpm" ];
      fedora = [ "terminus-fonts-console" "kbd" "gpm" ];
    };
    files.${program} = {
      mode = "0755";
      text = builtins.readFile ./console-font;
    };
    files."/etc/systemd/system/${unit}" = {
      text = ''
        [Unit]
        Description=Terminus console font sized to the display the machine booted on
        DefaultDependencies=no
        ConditionPathExists=/dev/tty0
        After=systemd-vconsole-setup.service
        Before=sysinit.target shutdown.target
        Conflicts=shutdown.target

        [Service]
        Type=oneshot
        ExecStart=${program}

        [Install]
        WantedBy=sysinit.target systemd-vconsole-setup.service
      '';
      reload = "systemctl daemon-reload";
    };
    units = [ "gpm.service" unit ];
    distros = [ "arch" "fedora" ];
  };

  checks = { pkgs, evalHome, ... }:
    let
      step = (import ./default.nix).linux.root;
      root = (evalHome { modules = [{ dotfiles.root.tty-console = step; }]; }).config.dotfiles.rootApplyScratch;
    in
    {
      tty-console-font = pkgs.runCommand "tty-console-font" { } ''
        export DOTFILES_ROOT_PREFIX=$TMPDIR/root FAKE=$TMPDIR/fake
        r=$DOTFILES_ROOT_PREFIX
        mkdir -p "$FAKE/bin"
        for tool in pacman dnf systemctl mkinitcpio dracut; do
          printf '#!/bin/sh\necho "%s $*" >> "$FAKE/calls"\n' "$tool" > "$FAKE/bin/$tool"
        done
        cat > "$FAKE/bin/setfont" <<'EOF'
        #!/bin/sh
        echo "setfont $*" >> "$FAKE/calls"
        [ ! -e "$FAKE/graphics-''${2##*/}" ]
        EOF
        chmod +x "$FAKE/bin"/*
        export PATH=$FAKE/bin:$PATH
        failures=0
        fail() { echo "FAIL $1"; cat "$FAKE/calls" 2>/dev/null; failures=$((failures + 1)); }
        calls() { cat "$FAKE/calls" 2>/dev/null; rm -f "$FAKE/calls"; }
        console() { mkdir -p "$r/sys/class/vc"; for n; do touch "$r/sys/class/vc/vcs$n" "$r/sys/class/vc/vcsa$n" "$r/sys/class/vc/vcsu$n"; done; touch "$r/sys/class/vc/vcs" "$r/sys/class/vc/vcsa"; }
        display() { mkdir -p "$r/sys/class/graphics/fb0"; echo "$1" > "$r/sys/class/graphics/fb0/virtual_size"; }

        apply() {
          rm -rf "$r" "$FAKE/calls"
          mkdir -p "$r/etc"
          echo "ID=$1" > "$r/etc/os-release"
          printf '%s\n' KEYMAP=us FONT=ter-132b > "$r/etc/vconsole.conf"
          echo 'HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)' > "$r/etc/mkinitcpio.conf"
          ${root}/bin/dotfiles-root-apply > "$TMPDIR/applied" 2>&1 || { cat "$TMPDIR/applied"; fail "$1: the root step succeeds"; }
          grep -qx "systemctl enable --now ${unit}" "$FAKE/calls" || fail "$1: the console font unit is enabled"
          if grep -Eq '^(mkinitcpio|dracut)' "$FAKE/calls"; then fail "$1: a switch rebuilds no initramfs"; fi
          if grep -q setfont "$FAKE/calls"; then fail "$1: the switch itself sets no font, the unit does"; fi
          [ "$(cat "$r/etc/vconsole.conf")" = "$(printf '%s\n' KEYMAP=us FONT=ter-132b)" ] && [ ! -e "$r/etc/vconsole.conf.pre-nix" ] \
            || fail "$1: vconsole.conf is left as it was"
          grep -qx 'WantedBy=sysinit.target systemd-vconsole-setup.service' "$r/etc/systemd/system/${unit}" \
            && grep -qx 'ExecStart=${program}' "$r/etc/systemd/system/${unit}" && [ -x "$r${program}" ] \
            || fail "$1: the unit runs the installed program at boot and after each console setup"
        }
        apply arch
        apply fedora
        calls > /dev/null

        pick() {
          said=$("$r${program}") || fail "the program succeeds for $1"
          [ "$(calls)" = "$2" ] || fail "$1: want $(printf '%s' "$2" | tr '\n' '|')"
        }
        console 1 2 3
        display 1920,1080
        pick "a 1080p display" "$(printf 'setfont -C /dev/tty%s ter-124b\n' 1 2 3)"
        display 3440,1440
        pick "a 1440p display" "$(printf 'setfont -C /dev/tty%s ter-132b\n' 1 2 3)"
        display 3840,2160
        pick "a 2160p display" "$(printf 'setfont -C /dev/tty%s ter-132b\n' 1 2 3)"
        display 1366,768
        pick "a 768p display" "$(printf 'setfont -C /dev/tty%s ter-118b\n' 1 2 3)"
        rm -r "$r/sys/class/graphics"
        pick "no framebuffer yet" "$(printf 'setfont -C /dev/tty%s ter-124b\n' 1 2 3)"
        display 1920,1080
        touch "$FAKE/graphics-tty1"
        pick "a console in graphics mode" "$(printf 'setfont -C /dev/tty%s ter-124b\n' 1 2 3)"
        [ "$said" = "console font ter-124b for a 1080px framebuffer on tty2 tty3" ] || fail "it names the consoles that took the font: $said"
        rm -r "$r/sys/class/vc"
        pick "no console allocated" ""

        [ "$failures" = 0 ]
        touch $out
      '';
    };
}
