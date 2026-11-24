{
  name = "QEMU and libvirt";
  description = "qemu, qemu-img, OVMF firmware, virtiofsd and libvirt, started as each distro expects it (libvirtd on Arch, the modular daemons' sockets on Fedora), with the user in the libvirt group. Headless too: VMs run there without a display.";
  platforms = [ "linux" ];

  linux.root = { lib, machine, ... }:
    let
      user = machine.user.name;
      fedoraSockets = [ "virtqemud.socket" "virtnetworkd.socket" "virtstoraged.socket" "virtproxyd.socket" ];
    in
    {
      packages = {
        arch = [ "qemu-system-x86" "edk2-ovmf" "virtiofsd" "libvirt" "qemu-img" ];
        fedora = [ "qemu-system-x86" "edk2-ovmf" "virtiofsd" "libvirt" "qemu-img" ];
      };
      script = ''
        getent group libvirt >/dev/null || groupadd --system libvirt
        case " $(id -nG ${lib.escapeShellArg user}) " in
          *" libvirt "*) ;;
          *)
            usermod -aG libvirt ${lib.escapeShellArg user}
            echo "added ${user} to the libvirt group; it applies at the next login"
            ;;
        esac
        case $DISTRO in
          arch) systemctl enable --now libvirtd.service ;;
          fedora) systemctl enable --now ${lib.concatStringsSep " " fedoraSockets} ;;
        esac
      '';
    };

  checks = { pkgs, evalHome, ... }:
    let
      step = (import ./qemu.nix).linux.root { lib = pkgs.lib; machine.user.name = "fixture"; };
      program = (evalHome { modules = [{ dotfiles.root.qemu = step // { packages = { }; }; }]; }).config.dotfiles.rootApplyScratch;
    in
    {
      libvirt-start = pkgs.runCommand "libvirt-start" { } ''
        export DOTFILES_ROOT_PREFIX=$TMPDIR/root FAKE=$TMPDIR/fake
        mkdir -p "$FAKE/bin"
        for tool in systemctl getent groupadd usermod; do
          printf '#!/bin/sh\necho "%s $*" >> "$FAKE/calls"\n' "$tool" > "$FAKE/bin/$tool"
        done
        printf '#!/bin/sh\necho libvirt\n' > "$FAKE/bin/id"
        chmod +x "$FAKE/bin"/*
        export PATH=$FAKE/bin:$PATH
        failures=0
        fail() { echo "FAIL $1"; cat "$FAKE/calls"; failures=$((failures + 1)); }
        run() { rm -rf "$DOTFILES_ROOT_PREFIX" "$FAKE/calls"; mkdir -p "$DOTFILES_ROOT_PREFIX/etc"; echo "ID=$1" > "$DOTFILES_ROOT_PREFIX/etc/os-release"; ${program}/bin/dotfiles-root-apply > /dev/null 2>&1 || true; }

        run arch
        grep -qx "systemctl enable --now libvirtd.service" "$FAKE/calls" || fail "Arch starts the monolithic libvirtd it expects"
        if grep -q virtqemud "$FAKE/calls"; then fail "Arch starts no modular daemon beside libvirtd"; fi
        run fedora
        grep -qx "systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket virtproxyd.socket" "$FAKE/calls" \
          || fail "Fedora starts the modular daemons' sockets it expects"
        if grep -q libvirtd "$FAKE/calls"; then fail "Fedora starts no monolithic libvirtd beside them"; fi

        [ "$failures" = 0 ]
        touch $out
      '';
    };
}
