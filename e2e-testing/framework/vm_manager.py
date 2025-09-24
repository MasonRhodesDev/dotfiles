#!/usr/bin/env python3
"""
VM Manager for E2E Testing

Integrates QEMU VM management with SSH and console monitoring.
"""

import os
import sys
import time
import logging
from typing import Dict, Optional, List
from pathlib import Path

import yaml

# Import local modules
sys.path.append(str(Path(__file__).parent))
from ssh_client import TestSSHClient
from console_monitor import ConsoleMonitor

# Import infrastructure modules
sys.path.append(str(Path(__file__).parent.parent / "infrastructure" / "qemu"))
from vm_manager import QEMUVMManager, VMSpec


class TestVMManager:
    """High-level VM manager for E2E testing"""

    def __init__(self, config_path: str = "../config/test_config.yaml"):
        self.config_path = Path(config_path)
        self.config = self._load_config()

        # Initialize components
        self.qemu_manager = QEMUVMManager()
        self.active_vms: Dict[str, Dict] = {}

        # Set up logging
        self.logger = logging.getLogger("test_vm_manager")

    def _load_config(self) -> Dict:
        """Load test configuration"""
        try:
            with open(self.config_path, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            raise RuntimeError(f"Failed to load test config: {e}")

    def create_test_vm(self, distribution: str, test_id: str = None) -> Dict:
        """Create and start a VM for testing"""
        self.logger.info(f"Creating test VM for {distribution}")

        # Create VM specification
        vm_spec = self.qemu_manager.create_vm_spec(distribution, test_id)

        # Start VM
        vm_info = self.qemu_manager.start_vm(vm_spec)

        # Wait for VM to boot
        self.logger.info(f"Waiting for VM {vm_spec.name} to boot...")
        time.sleep(30)  # Give VM time to start

        # Create SSH client
        ssh_client = TestSSHClient(
            hostname="localhost",
            port=vm_spec.ssh_port,
            username=self.config["chezmoi"]["test_user"],
            password=self.config["chezmoi"]["test_user_password"],
            timeout=self.config["test"]["ssh_connect_timeout"]
        )

        # Create console monitor
        console_monitor = ConsoleMonitor(
            test_name=f"{distribution}_{vm_spec.name}",
            config=self.config
        )

        # Prepare test VM info
        test_vm_info = {
            "vm_spec": vm_spec,
            "vm_info": vm_info,
            "ssh_client": ssh_client,
            "console_monitor": console_monitor,
            "distribution": distribution,
            "created_at": time.time()
        }

        self.active_vms[vm_spec.name] = test_vm_info

        # Connect SSH
        if not ssh_client.connect():
            raise RuntimeError(f"Failed to establish SSH connection to {vm_spec.name}")

        # Start console monitoring
        console_monitor.start_monitoring()

        self.logger.info(f"Test VM {vm_spec.name} created and ready")
        return test_vm_info

    def install_chezmoi(self, vm_name: str) -> bool:
        """Install chezmoi on the test VM"""
        if vm_name not in self.active_vms:
            raise ValueError(f"VM {vm_name} not found")

        vm_info = self.active_vms[vm_name]
        ssh_client = vm_info["ssh_client"]
        monitor = vm_info["console_monitor"]
        distribution = vm_info["distribution"]

        self.logger.info(f"Installing chezmoi on {vm_name} ({distribution})")

        # Get installation command from config
        dist_config = self.config["distributions"][distribution]
        install_cmd = dist_config["chezmoi_install_cmd"]

        # Execute installation
        monitor.add_log_entry("system", f"Starting chezmoi installation: {install_cmd}")

        for stream_type, content in ssh_client.execute_command_stream(
            install_cmd,
            timeout=self.config["test"]["chezmoi_init_timeout"]
        ):
            if stream_type in ["stdout", "stderr"]:
                monitor.add_log_entry(stream_type, content)
            elif stream_type == "exit_code":
                if content == 0:
                    monitor.add_log_entry("system", "Chezmoi installation completed successfully")
                    return True
                else:
                    monitor.add_log_entry("system", f"Chezmoi installation failed with exit code: {content}")
                    return False
            elif stream_type == "error":
                monitor.add_log_entry("stderr", f"Installation error: {content}")
                return False

        return False

    def run_chezmoi_init(self, vm_name: str) -> bool:
        """Run chezmoi init on the test VM"""
        if vm_name not in self.active_vms:
            raise ValueError(f"VM {vm_name} not found")

        vm_info = self.active_vms[vm_name]
        ssh_client = vm_info["ssh_client"]
        monitor = vm_info["console_monitor"]

        self.logger.info(f"Running chezmoi init on {vm_name}")

        repo_url = self.config["chezmoi"]["repo_url"]
        branch = self.config["chezmoi"]["branch"]

        init_cmd = f"chezmoi init --branch {branch} {repo_url}"

        monitor.add_log_entry("system", f"Starting chezmoi init: {init_cmd}")

        for stream_type, content in ssh_client.execute_command_stream(
            init_cmd,
            timeout=self.config["test"]["chezmoi_init_timeout"]
        ):
            if stream_type in ["stdout", "stderr"]:
                monitor.add_log_entry(stream_type, content)
            elif stream_type == "exit_code":
                if content == 0:
                    monitor.add_log_entry("system", "Chezmoi init completed successfully")
                    return True
                else:
                    monitor.add_log_entry("system", f"Chezmoi init failed with exit code: {content}")
                    return False
            elif stream_type == "error":
                monitor.add_log_entry("stderr", f"Init error: {content}")
                return False

        return False

    def run_chezmoi_apply(self, vm_name: str) -> bool:
        """Run chezmoi apply on the test VM"""
        if vm_name not in self.active_vms:
            raise ValueError(f"VM {vm_name} not found")

        vm_info = self.active_vms[vm_name]
        ssh_client = vm_info["ssh_client"]
        monitor = vm_info["console_monitor"]

        self.logger.info(f"Running chezmoi apply on {vm_name}")

        apply_cmd = "chezmoi apply -v"

        monitor.add_log_entry("system", f"Starting chezmoi apply: {apply_cmd}")

        for stream_type, content in ssh_client.execute_command_stream(
            apply_cmd,
            timeout=self.config["test"]["chezmoi_apply_timeout"]
        ):
            if stream_type in ["stdout", "stderr"]:
                monitor.add_log_entry(stream_type, content)
            elif stream_type == "exit_code":
                if content == 0:
                    monitor.add_log_entry("system", "Chezmoi apply completed successfully")
                    return True
                else:
                    monitor.add_log_entry("system", f"Chezmoi apply failed with exit code: {content}")
                    return False
            elif stream_type == "error":
                monitor.add_log_entry("stderr", f"Apply error: {content}")
                return False

        return False

    def run_software_installers(self, vm_name: str) -> bool:
        """Run software installer scripts on the test VM"""
        if vm_name not in self.active_vms:
            raise ValueError(f"VM {vm_name} not found")

        vm_info = self.active_vms[vm_name]
        ssh_client = vm_info["ssh_client"]
        monitor = vm_info["console_monitor"]

        self.logger.info(f"Running software installers on {vm_name}")

        # Find and run executable scripts in software_installers directory
        find_cmd = "find ~/.local/share/chezmoi/software_installers -name 'executable_*.sh' | sort"

        exit_code, stdout, stderr = ssh_client.execute_command(find_cmd, timeout=30)
        if exit_code != 0:
            monitor.add_log_entry("stderr", f"Failed to find installer scripts: {stderr}")
            return False

        scripts = [line.strip() for line in stdout.split('\n') if line.strip()]

        if not scripts:
            monitor.add_log_entry("system", "No installer scripts found")
            return True

        monitor.add_log_entry("system", f"Found {len(scripts)} installer scripts")

        # Run each script
        for script in scripts:
            script_name = Path(script).name
            monitor.add_log_entry("system", f"Running installer: {script_name}")

            # Make script executable and run it
            chmod_cmd = f"chmod +x {script}"
            exit_code, _, stderr = ssh_client.execute_command(chmod_cmd, timeout=10)
            if exit_code != 0:
                monitor.add_log_entry("stderr", f"Failed to make {script_name} executable: {stderr}")
                continue

            # Execute the installer
            for stream_type, content in ssh_client.execute_command_stream(
                script,
                timeout=600  # 10 minutes per installer
            ):
                if stream_type in ["stdout", "stderr"]:
                    monitor.add_log_entry(stream_type, content)
                elif stream_type == "exit_code":
                    if content == 0:
                        monitor.add_log_entry("system", f"Installer {script_name} completed successfully")
                    else:
                        monitor.add_log_entry("system", f"Installer {script_name} failed with exit code: {content}")
                        # Continue with other installers even if one fails
                elif stream_type == "error":
                    monitor.add_log_entry("stderr", f"Installer {script_name} error: {content}")

        monitor.add_log_entry("system", "Software installer execution completed")
        return True

    def validate_installation(self, vm_name: str) -> Dict:
        """Validate the chezmoi installation on the test VM"""
        if vm_name not in self.active_vms:
            raise ValueError(f"VM {vm_name} not found")

        vm_info = self.active_vms[vm_name]
        ssh_client = vm_info["ssh_client"]
        monitor = vm_info["console_monitor"]

        self.logger.info(f"Validating installation on {vm_name}")

        validation_results = {
            "chezmoi_status": False,
            "config_files_present": False,
            "services_running": False,
            "errors": []
        }

        # Check chezmoi status
        exit_code, stdout, stderr = ssh_client.execute_command("chezmoi status", timeout=30)
        if exit_code == 0:
            validation_results["chezmoi_status"] = True
            monitor.add_log_entry("system", "Chezmoi status check passed")
        else:
            validation_results["errors"].append(f"Chezmoi status failed: {stderr}")
            monitor.add_log_entry("stderr", f"Chezmoi status check failed: {stderr}")

        # Check for key configuration files
        config_checks = [
            "~/.config/nvim/init.lua",
            "~/.config/hypr/hyprland.conf",
            "~/.bashrc",
        ]

        config_files_found = 0
        for config_file in config_checks:
            exit_code, _, _ = ssh_client.execute_command(f"test -f {config_file}", timeout=10)
            if exit_code == 0:
                config_files_found += 1
                monitor.add_log_entry("system", f"Config file found: {config_file}")
            else:
                monitor.add_log_entry("system", f"Config file missing: {config_file}")

        validation_results["config_files_present"] = config_files_found > 0

        # Check if systemd services are running (if any)
        exit_code, stdout, stderr = ssh_client.execute_command(
            "systemctl --user list-units --state=active --no-pager",
            timeout=30
        )
        if exit_code == 0:
            validation_results["services_running"] = True
            monitor.add_log_entry("system", "Systemd services check passed")

        return validation_results

    def cleanup_vm(self, vm_name: str) -> None:
        """Clean up test VM resources"""
        if vm_name not in self.active_vms:
            return

        self.logger.info(f"Cleaning up VM {vm_name}")

        vm_info = self.active_vms[vm_name]

        # Stop console monitoring
        if vm_info["console_monitor"]:
            vm_info["console_monitor"].stop_monitoring()

        # Close SSH connection
        if vm_info["ssh_client"]:
            vm_info["ssh_client"].close()

        # Clean up VM
        self.qemu_manager.cleanup_vm(vm_name)

        # Remove from active VMs
        del self.active_vms[vm_name]

    def cleanup_all(self) -> None:
        """Clean up all test VMs"""
        for vm_name in list(self.active_vms.keys()):
            self.cleanup_vm(vm_name)

    def get_vm_status(self, vm_name: str) -> Optional[Dict]:
        """Get status of a test VM"""
        if vm_name not in self.active_vms:
            return None

        vm_info = self.active_vms[vm_name]
        monitor = vm_info["console_monitor"]

        return {
            "vm_name": vm_name,
            "distribution": vm_info["distribution"],
            "ssh_connected": vm_info["ssh_client"].is_connected(),
            "monitoring_active": monitor.is_monitoring,
            "errors_found": len(monitor.get_errors()),
            "fatal_errors": monitor.has_fatal_errors(),
            "successes_found": len(monitor.get_successes()),
            "uptime_seconds": time.time() - vm_info["created_at"]
        }

    def export_vm_logs(self, vm_name: str, output_dir: str) -> bool:
        """Export logs from a test VM"""
        if vm_name not in self.active_vms:
            return False

        vm_info = self.active_vms[vm_name]
        monitor = vm_info["console_monitor"]

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        log_file = output_path / f"{vm_name}_console.log"
        json_file = output_path / f"{vm_name}_console.json"

        # Export in both formats
        success = True
        success &= monitor.export_logs(str(log_file), "text")
        success &= monitor.export_logs(str(json_file), "json")

        return success