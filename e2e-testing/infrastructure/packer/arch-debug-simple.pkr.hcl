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

  # Config drive
  qemuargs = [
    ["-drive", "file=fat:rw:archinstall,format=raw,media=disk"]
  ]

  # Boot configuration - minimal, just get to shell
  boot_wait = "30s"
  boot_command = [
    "<enter><wait10>",
    "echo 'Booted into Arch ISO'<enter>",
    "lsblk<enter>",
    "echo 'Mounting config drive'<enter>",
    "mkdir /mnt/config && mount /dev/sdb1 /mnt/config<enter>",
    "ls -la /mnt/config/<enter>",
    "cp /mnt/config/*.json /tmp/<enter>",
    "cat /tmp/user_configuration.json<enter>",
    "echo 'About to run archinstall - press Ctrl+C if needed'<enter>",
    "sleep 5<enter>",
    "archinstall --config /tmp/user_configuration.json --creds /tmp/user_credentials.json --debug<enter>"
    # No more commands - let it run and we'll watch via VNC
  ]

  # SSH configuration required even for debug
  ssh_username = "root"
  ssh_password = "root"
  ssh_timeout = "1m"

  # Output
  vm_name      = "arch-debug"
  output_directory = "../images/debug/"

  # VNC for watching
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5902
  vnc_port_max     = 5902

  # Don't shutdown - leave it running
  shutdown_command = "echo 'Debug mode - staying alive'"
}

build {
  sources = ["source.qemu.arch-base"]

  provisioner "shell" {
    inline = ["echo 'This will not run - debug mode'"]
    timeout = "1m"
    expect_disconnect = true
  }
}