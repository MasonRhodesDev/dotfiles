{
  name = "FW16 kernel cmdline";
  description = "Kernel arguments for the dGPU module, set through grubby on Fedora.";
  platforms = [ "linux" ];

  linux.root = {
    distros = [ "fedora" ];
    script = ''
      want="amdgpu.ppfeaturemask=0xffffffff amdgpu.gpu_recovery=1 pci_aspm=off amdgpu.cwsr_enable=0"

      vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
      product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
      case "$vendor:$product" in
          Framework:*Laptop\ 16*) ;;
          *) echo "not a Framework Laptop 16 ($vendor / $product), kernel arguments left alone"; exit 0 ;;
      esac

      command -v grubby >/dev/null || { echo "grubby not found, kernel arguments not set"; exit 1; }

      has_all() {
          local a
          for a in $want; do
              case " $1 " in *" $a "*) ;; *) return 1 ;; esac
          done
      }

      info=$(grubby --info=ALL)
      entries=$(printf '%s\n' "$info" | sed -n 's/^args="\(.*\)"$/\1/p')
      [ -n "$entries" ] || { echo "grubby --info=ALL listed no entry args, kernel arguments not set"; exit 1; }
      stale=0
      while IFS= read -r args; do
          has_all "$args" || stale=1
      done <<< "$entries"
      if [ -f /etc/kernel/cmdline ]; then
          has_all "$(cat /etc/kernel/cmdline)" || stale=1
      fi
      if [ -f /etc/default/grub ]; then
          grub=$(. /etc/default/grub; echo "''${GRUB_CMDLINE_LINUX-}")
          [ -z "$grub" ] || has_all "$grub" || stale=1
      fi

      if [ "$stale" = 1 ]; then
          grubby --update-kernel=ALL --args="$want"
          echo "kernel arguments set for every boot entry"
      fi
      has_all "$(cat /proc/cmdline)" || echo "reboot to boot with: $want"
    '';
  };

  inventory = {
    scripts = [
      {
        id = "51-fw16-grub-cmdline";
        root = true;
      }
    ];
  };
}
