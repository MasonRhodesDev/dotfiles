#!/usr/bin/env python3
"""
QEMU VM Management for Chezmoi E2E Testing

Handles VM lifecycle operations including creation, startup, shutdown, and cleanup.
"""

import os
import sys
import json
import time
import uuid
import shutil
import socket
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass

import yaml


@dataclass
class VMSpec:
    """VM specification configuration"""
    name: str
    distribution: str
    base_image: str
    memory_mb: int
    cpu_cores: int
    disk_size_gb: int
    ssh_port: int
    vnc_port: int
    monitor_socket: str


class QEMUVMManager:
    """Manages QEMU virtual machines for testing"""

    def __init__(self, config_path: str = "../../config/vm_config.yaml"):
        self.script_dir = Path(__file__).parent
        self.config_path = Path(config_path)
        self.config = self._load_config()
        self.base_images_dir = self.script_dir / "images" / "base"
        self.test_images_dir = self.script_dir / "images" / "test"
        self.temp_dir = self.script_dir / "temp"
        self.running_vms: Dict[str, Dict] = {}

        # Ensure directories exist
        self.base_images_dir.mkdir(parents=True, exist_ok=True)
        self.test_images_dir.mkdir(parents=True, exist_ok=True)
        self.temp_dir.mkdir(parents=True, exist_ok=True)

    def _load_config(self) -> Dict:
        """Load VM configuration from YAML file"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            raise RuntimeError(f"Failed to load VM config: {e}")

    def _find_free_port(self, start_port: int = 2222) -> int:
        """Find an available port starting from start_port"""
        for port in range(start_port, start_port + 1000):
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.bind(('localhost', port))
                sock.close()
                return port
            except OSError:
                continue
        raise RuntimeError("No free ports available")

    def create_vm_spec(self, distribution: str, test_id: str = None) -> VMSpec:
        """Create VM specification for given distribution"""
        if test_id is None:
            test_id = str(uuid.uuid4())[:8]

        vm_config = self.config["vm"]
        dist_config = self.config["distributions"][distribution]

        if not dist_config["enabled"]:
            raise ValueError(f"Distribution {distribution} is not enabled")

        ssh_port = self._find_free_port(2222)
        vnc_port = self._find_free_port(5900)

        return VMSpec(
            name=f"{distribution}-{test_id}",
            distribution=distribution,
            base_image=dist_config["base_image"],
            memory_mb=vm_config["memory_mb"],
            cpu_cores=vm_config["cpu_cores"],
            disk_size_gb=vm_config["disk_size_gb"],
            ssh_port=ssh_port,
            vnc_port=vnc_port,
            monitor_socket=str(self.temp_dir / f"qemu-{distribution}-{test_id}.sock")
        )

    def create_cloud_init_iso(self, vm_spec: VMSpec, ssh_public_key: str = None) -> Path:
        """Create cloud-init ISO for VM initialization"""
        cloud_init_dir = self.temp_dir / f"cloud-init-{vm_spec.name}"
        cloud_init_dir.mkdir(exist_ok=True)

        # User data configuration
        user_data = {
            "users": [
                {
                    "name": "testuser",
                    "sudo": "ALL=(ALL) NOPASSWD:ALL",
                    "shell": "/bin/bash",
                    "ssh_authorized_keys": [ssh_public_key] if ssh_public_key else []
                }
            ],
            "packages": ["openssh-server"],
            "runcmd": [
                "systemctl enable ssh",
                "systemctl start ssh"
            ]
        }

        # Meta data
        meta_data = {
            "instance-id": vm_spec.name,
            "local-hostname": vm_spec.name
        }

        # Write cloud-init files
        user_data_file = cloud_init_dir / "user-data"
        meta_data_file = cloud_init_dir / "meta-data"

        with open(user_data_file, 'w') as f:
            f.write("#cloud-config\n")
            yaml.dump(user_data, f)

        with open(meta_data_file, 'w') as f:
            yaml.dump(meta_data, f)

        # Create ISO
        iso_path = self.temp_dir / f"cloud-init-{vm_spec.name}.iso"
        cmd = [
            "genisoimage",
            "-output", str(iso_path),
            "-volid", "cidata",
            "-joliet",
            "-rock",
            str(user_data_file),
            str(meta_data_file)
        ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            return iso_path
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to create cloud-init ISO: {e}")

    def create_vm_image(self, vm_spec: VMSpec) -> Path:
        """Create VM disk image from base image"""
        base_image_path = self.base_images_dir / vm_spec.base_image
        if not base_image_path.exists():
            raise FileNotFoundError(f"Base image not found: {base_image_path}")

        vm_image_path = self.test_images_dir / f"{vm_spec.name}.qcow2"

        # Create backing image
        cmd = [
            "qemu-img", "create",
            "-f", "qcow2",
            "-b", str(base_image_path),
            "-F", "qcow2",
            str(vm_image_path)
        ]

        try:
            subprocess.run(cmd, check=True, capture_output=True)
            return vm_image_path
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to create VM image: {e}")

    def start_vm(self, vm_spec: VMSpec, ssh_public_key: str = None) -> Dict:
        """Start QEMU virtual machine"""
        # Create VM disk image
        vm_image_path = self.create_vm_image(vm_spec)

        # Create cloud-init ISO
        cloud_init_iso = self.create_cloud_init_iso(vm_spec, ssh_public_key)

        # Build QEMU command
        qemu_config = self.config["qemu"]

        cmd = [
            "qemu-system-x86_64",
            "-machine", qemu_config["machine_type"],
            "-cpu", "host",
            "-smp", str(vm_spec.cpu_cores),
            "-m", str(vm_spec.memory_mb),
            "-drive", f"file={vm_image_path},format=qcow2,if=virtio",
            "-drive", f"file={cloud_init_iso},media=cdrom,if=ide",
            "-netdev", f"user,id=net0,hostfwd=tcp::{vm_spec.ssh_port}-:22",
            "-device", "virtio-net,netdev=net0",
            "-vnc", f":{vm_spec.vnc_port - 5900}",
            "-monitor", f"unix:{vm_spec.monitor_socket},server,nowait",
            "-daemonize",
            "-pidfile", str(self.temp_dir / f"{vm_spec.name}.pid")
        ]

        # Add KVM acceleration if available
        if os.path.exists("/dev/kvm"):
            cmd.extend(["-accel", "kvm"])
        else:
            cmd.extend(["-accel", "tcg"])

        # Start VM
        try:
            subprocess.run(cmd, check=True, capture_output=True)
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Failed to start VM: {e}")

        # Store VM information
        vm_info = {
            "spec": vm_spec,
            "image_path": vm_image_path,
            "cloud_init_iso": cloud_init_iso,
            "pid_file": self.temp_dir / f"{vm_spec.name}.pid",
            "started_at": time.time()
        }

        self.running_vms[vm_spec.name] = vm_info
        return vm_info

    def stop_vm(self, vm_name: str, force: bool = False) -> bool:
        """Stop virtual machine"""
        if vm_name not in self.running_vms:
            return False

        vm_info = self.running_vms[vm_name]
        pid_file = vm_info["pid_file"]

        try:
            # Try graceful shutdown first via monitor
            if not force:
                self._send_monitor_command(vm_info["spec"].monitor_socket, "system_powerdown")
                time.sleep(10)  # Wait for graceful shutdown

            # Force kill if needed
            if pid_file.exists():
                with open(pid_file, 'r') as f:
                    pid = int(f.read().strip())
                try:
                    os.kill(pid, 15)  # SIGTERM
                    time.sleep(2)
                    os.kill(pid, 9)   # SIGKILL if still running
                except ProcessLookupError:
                    pass  # Process already dead

            return True
        except Exception as e:
            print(f"Error stopping VM {vm_name}: {e}")
            return False

    def cleanup_vm(self, vm_name: str) -> None:
        """Clean up VM resources"""
        if vm_name not in self.running_vms:
            return

        vm_info = self.running_vms[vm_name]

        # Stop VM
        self.stop_vm(vm_name, force=True)

        # Remove files
        try:
            if vm_info["image_path"].exists():
                vm_info["image_path"].unlink()
            if vm_info["cloud_init_iso"].exists():
                vm_info["cloud_init_iso"].unlink()
            if vm_info["pid_file"].exists():
                vm_info["pid_file"].unlink()

            # Remove monitor socket
            monitor_socket = Path(vm_info["spec"].monitor_socket)
            if monitor_socket.exists():
                monitor_socket.unlink()

        except Exception as e:
            print(f"Error cleaning up VM {vm_name}: {e}")

        # Remove from running VMs
        del self.running_vms[vm_name]

    def _send_monitor_command(self, socket_path: str, command: str) -> str:
        """Send command to QEMU monitor"""
        try:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            sock.connect(socket_path)
            sock.send(f"{command}\n".encode())
            response = sock.recv(1024).decode()
            sock.close()
            return response
        except Exception:
            return ""

    def list_running_vms(self) -> List[str]:
        """List currently running VMs"""
        return list(self.running_vms.keys())

    def get_vm_info(self, vm_name: str) -> Optional[Dict]:
        """Get information about a running VM"""
        return self.running_vms.get(vm_name)

    def cleanup_all(self) -> None:
        """Clean up all running VMs"""
        for vm_name in list(self.running_vms.keys()):
            self.cleanup_vm(vm_name)


def main():
    """CLI interface for VM management"""
    import argparse

    parser = argparse.ArgumentParser(description="QEMU VM Manager for E2E Testing")
    parser.add_argument("command", choices=["start", "stop", "cleanup", "list"])
    parser.add_argument("--distribution", choices=["arch", "fedora"], help="Linux distribution")
    parser.add_argument("--vm-name", help="VM name")
    parser.add_argument("--test-id", help="Test ID for VM naming")

    args = parser.parse_args()

    manager = QEMUVMManager()

    try:
        if args.command == "start":
            if not args.distribution:
                print("Error: --distribution required for start command")
                sys.exit(1)

            spec = manager.create_vm_spec(args.distribution, args.test_id)
            vm_info = manager.start_vm(spec)
            print(f"Started VM: {spec.name}")
            print(f"SSH port: {spec.ssh_port}")
            print(f"VNC port: {spec.vnc_port}")

        elif args.command == "stop":
            if not args.vm_name:
                print("Error: --vm-name required for stop command")
                sys.exit(1)

            if manager.stop_vm(args.vm_name):
                print(f"Stopped VM: {args.vm_name}")
            else:
                print(f"VM not found: {args.vm_name}")

        elif args.command == "cleanup":
            if args.vm_name:
                manager.cleanup_vm(args.vm_name)
                print(f"Cleaned up VM: {args.vm_name}")
            else:
                manager.cleanup_all()
                print("Cleaned up all VMs")

        elif args.command == "list":
            vms = manager.list_running_vms()
            if vms:
                print("Running VMs:")
                for vm_name in vms:
                    info = manager.get_vm_info(vm_name)
                    spec = info["spec"]
                    print(f"  {vm_name} (SSH: {spec.ssh_port}, VNC: {spec.vnc_port})")
            else:
                print("No running VMs")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()