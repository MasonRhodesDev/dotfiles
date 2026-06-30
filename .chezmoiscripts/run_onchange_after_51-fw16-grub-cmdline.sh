#!/bin/bash
# Framework 16 (AMD) kernel command-line params for dGPU stability:
#   amdgpu.ppfeaturemask=0xffffffff   full power-management feature set
#   amdgpu.gpu_recovery=1             recover from GPU hangs vs hard-lock
#   pci_aspm=off                      dGPU D3cold/ASPM resume-wedge workaround
#   amdgpu.cwsr_enable=0              reduce GPU reset latency
# HARDWARE-GATED to a Framework Laptop 16. Idempotent: only acts on missing args.
# Fedora BLS path: /etc/kernel/cmdline (future kernels) + grubby (installed ones).
set -euo pipefail

vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)
product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
case "$vendor:$product" in
    Framework:*Laptop\ 16*) : ;;
    *) echo "Not a Framework Laptop 16 ($vendor / $product) — skipping GRUB cmdline"; exit 0 ;;
esac

ARGS="amdgpu.ppfeaturemask=0xffffffff amdgpu.gpu_recovery=1 pci_aspm=off amdgpu.cwsr_enable=0"

missing=""
for a in $ARGS; do
    grep -qw -- "$a" /proc/cmdline 2>/dev/null || missing="$missing $a"
done

# Future kernels inherit from /etc/kernel/cmdline on Fedora's BLS setup.
if [ -f /etc/kernel/cmdline ]; then
    cur=$(cat /etc/kernel/cmdline); add=""
    for a in $ARGS; do case " $cur " in *" $a "*) ;; *) add="$add $a" ;; esac; done
    if [ -n "$add" ]; then
        echo "Adding to /etc/kernel/cmdline:$add"
        printf '%s\n' "$cur$add" | sudo tee /etc/kernel/cmdline >/dev/null
    fi
fi

# Installed kernel entries (grubby dedups args, so this is idempotent).
if command -v grubby >/dev/null 2>&1; then
    sudo grubby --update-kernel=ALL --args="$ARGS" >/dev/null || true
fi

if [ -n "$missing" ]; then
    echo "✓ Framework 16 GRUB params ensured; reboot to activate:$missing"
else
    echo "GRUB cmdline already complete — nothing to do"
fi
