packer {
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "fedora-base" {
  # ISO configuration
  iso_url      = "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-netinst-x86_64-39-1.5.iso"
  iso_checksum = "sha256:e11a7c33875c15c3b4bf013a8e4c8fa0f46d5a93f30d7b4d6b1be8b8de3ce8b6"

  # VM specifications
  memory       = 2048
  cpus         = 2
  disk_size    = "40G"
  format       = "qcow2"
  accelerator  = "kvm"

  # Networking
  net_device = "virtio-net"

  # Boot configuration - Fedora automated install
  boot_wait = "10s"
  boot_command = [
    "<tab> text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/fedora-kickstart.cfg<enter><wait>"
  ]

  # HTTP server for kickstart file
  http_directory = "kickstart"
  http_port_min  = 8000
  http_port_max  = 8100

  # SSH configuration
  ssh_username = "testuser"
  ssh_password = "testpass123"
  ssh_timeout = "30m"

  # Output
  vm_name      = "fedora-base"
  output_directory = "../images/base/fedora/"

  # VNC for monitoring
  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5902
  vnc_port_max     = 5902

  # Shutdown
  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.qemu.fedora-base"]

  # Wait for SSH to be available
  provisioner "shell" {
    inline = ["echo 'SSH connection established'"]
  }

  # Update system and install essential packages
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y openssh-server cloud-init git curl wget",
      "sudo systemctl enable sshd",
      "sudo systemctl enable cloud-init"
    ]
  }

  # Configure cloud-init for automated setup
  provisioner "shell" {
    inline = [
      "sudo echo 'datasource_list: [NoCloud]' > /etc/cloud/cloud.cfg.d/99_datasource.cfg",
      "sudo systemctl enable cloud-init-local",
      "sudo systemctl enable cloud-config",
      "sudo systemctl enable cloud-final"
    ]
  }

  # Clean up for template use
  provisioner "shell" {
    inline = [
      "sudo dnf clean all",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c",
      "cat /dev/null > ~/.bash_history"
    ]
  }
}