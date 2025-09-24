#!/bin/bash

# Test QEMU directly without Packer to see what's wrong

echo "Testing QEMU setup directly..."

# Download Arch ISO if not present
ISO_PATH="/tmp/archlinux-x86_64.iso"
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Arch ISO..."
    curl -L -o "$ISO_PATH" "https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
fi

# Create test disk
TEST_DISK="/tmp/test-disk.qcow2"
qemu-img create -f qcow2 "$TEST_DISK" 10G

echo "Starting QEMU with:"
echo "  ISO: $ISO_PATH"
echo "  Disk: $TEST_DISK"
echo "  VNC: localhost:5901"
echo ""
echo "Connect with VNC viewer to see what happens"
echo "Press Ctrl+C to stop"

# Run QEMU directly with minimal config
qemu-system-x86_64 \
    -machine q35 \
    -cpu host \
    -accel kvm \
    -m 2048 \
    -cdrom "$ISO_PATH" \
    -drive file="$TEST_DISK",format=qcow2,if=virtio \
    -boot order=dc \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -vnc :1 \
    -no-reboot

echo "QEMU exited"