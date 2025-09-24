packer {
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "arch-base" {
  # ISO configuration
  iso_url      = "https://mirrors.kernel.org/archlinux/iso/latest/archlinux-x86_64.iso"
  iso_checksum = "file:https://mirrors.kernel.org/archlinux/iso/latest/sha256sums.txt"

  # VM specifications
  memory       = 4096
  cpus         = 2
  disk_size    = "40G"
  format       = "qcow2"
  accelerator  = "kvm"

  # Additional drives for config files - mount archinstall directory as FAT drive
  qemuargs = [
    ["-drive", "file=fat:rw:archinstall,format=raw,media=disk"],
    ["-boot", "order=dc"]  # Boot from disk first, then CD-ROM
  ]

  # Boot configuration
  boot_wait = "30s"
  boot_command = [
    # Wait for boot prompt
    "<enter><wait10>",
    # Show available disks
    "lsblk<enter><wait2>",
    # Mount the config drive (should be /dev/sdb1)
    "mkdir /mnt/config<enter>",
    "mount /dev/sdb1 /mnt/config<enter>",
    # List files on config drive
    "ls -la /mnt/config/<enter>",
    # Copy config files
    "cp /mnt/config/user_configuration.json /tmp/<enter>",
    "cp /mnt/config/user_credentials.json /tmp/<enter>",
    # Verify files were copied
    "ls -la /tmp/user_*.json<enter>",
    # Show config content for debugging
    "echo '=== CONFIG CONTENT ==='<enter>",
    "cat /tmp/user_configuration.json<enter>",
    # Run archinstall with debug output - DON'T wait blindly
    "echo '=== STARTING ARCHINSTALL ==='<enter>",
    "archinstall --config /tmp/user_configuration.json --creds /tmp/user_credentials.json --debug 2>&1 | tee /tmp/install.log<enter>",
    # Wait longer for archinstall to finish
    "<wait300>",
    "echo '=== ARCHINSTALL STATUS ==='<enter>",
    "echo 'Exit code:' $?<enter>",
    "echo '=== INSTALLATION LOG ==='<enter>",
    "tail -20 /tmp/install.log<enter>",
    "echo '=== CHECKING DISK ==='<enter>",
    "fdisk -l /dev/vda<enter>",
    "lsblk<enter>",
    "echo '=== CHECKING MOUNT POINTS ==='<enter>",
    "mount | grep vda<enter>",
    # Don't poweroff yet - let's see what happened
    "echo '=== READY FOR MANUAL INSPECTION ==='<enter>"
  ]


  # SSH configuration (after reboot)
  ssh_username = "testuser"
  ssh_password = "testpass123"
  ssh_timeout = "30m"

  # Output
  vm_name      = "arch-base"
  output_directory = "../images/base/arch/"

  # VNC for monitoring
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5901
  vnc_port_max     = 5901

  # Shutdown
  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.qemu.arch-base"]

  provisioner "shell" {
    inline = ["echo 'SSH connection established after archinstall'"]
  }

  provisioner "shell" {
    inline = [
      "sudo systemctl enable sshd",
      "sudo systemctl enable cloud-init",
      "sudo systemctl enable NetworkManager"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /etc/cloud/cloud.cfg.d",
      "echo 'datasource_list: [NoCloud]' | sudo tee /etc/cloud/cloud.cfg.d/99_datasource.cfg",
      "sudo systemctl enable cloud-init-local",
      "sudo systemctl enable cloud-config",
      "sudo systemctl enable cloud-final"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo pacman -Scc --noconfirm",
      "sudo rm -rf /var/cache/pacman/pkg/*",
      "sudo rm -rf /tmp/*",
      "history -c"
    ]
  }
}