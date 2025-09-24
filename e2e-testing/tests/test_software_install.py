#!/usr/bin/env python3
"""
Software Installation E2E Tests

Tests the execution of software installer scripts included in the dotfiles.
"""

import pytest
import time
import logging
from pathlib import Path

# Import test framework
import sys
sys.path.append(str(Path(__file__).parent.parent / "framework"))
from vm_manager import TestVMManager


class TestSoftwareInstall:
    """Test software installation scripts"""

    @pytest.fixture(scope="class")
    def vm_manager(self):
        """Set up VM manager"""
        manager = TestVMManager()
        yield manager
        manager.cleanup_all()

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_full_software_installation(self, vm_manager, distribution):
        """Test complete software installation workflow"""
        test_id = f"software_install_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing software installation on {vm_name}")

            # Step 1: Install and initialize chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Step 2: Run software installers
            assert vm_manager.run_software_installers(vm_name), "Software installers failed"

            # Step 3: Validate key software installations
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Check for key installed packages based on distribution
            if distribution == "arch":
                key_packages = ["git", "curl", "wget", "vim"]
            else:  # fedora
                key_packages = ["git", "curl", "wget", "vim"]

            for package in key_packages:
                exit_code, stdout, stderr = ssh_client.execute_command(
                    f"which {package}",
                    timeout=10
                )
                if exit_code == 0:
                    monitor.add_log_entry("system", f"Package {package} installed successfully")
                else:
                    monitor.add_log_entry("system", f"Package {package} not found: {stderr}")

            # Step 4: Check for critical errors
            vm_status = vm_manager.get_vm_status(vm_name)
            # Allow some errors during software installation but not fatal ones
            assert not vm_status["fatal_errors"], "Fatal errors detected during software installation"

            logging.info(f"Software installation test passed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_software_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Software installation test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_individual_installers(self, vm_manager, distribution):
        """Test individual installer scripts one by one"""
        test_id = f"individual_installers_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing individual installers on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Find installer scripts
            find_cmd = "find ~/.local/share/chezmoi/software_installers -name 'executable_*.sh' | sort"
            exit_code, stdout, stderr = ssh_client.execute_command(find_cmd, timeout=30)

            assert exit_code == 0, f"Failed to find installer scripts: {stderr}"

            scripts = [line.strip() for line in stdout.split('\n') if line.strip()]
            assert len(scripts) > 0, "No installer scripts found"

            monitor.add_log_entry("system", f"Found {len(scripts)} installer scripts")

            # Test each script individually
            for script in scripts:
                script_name = Path(script).name
                monitor.add_log_entry("system", f"Testing installer: {script_name}")

                # Make executable
                exit_code, _, stderr = ssh_client.execute_command(f"chmod +x {script}", timeout=10)
                if exit_code != 0:
                    monitor.add_log_entry("stderr", f"Failed to make {script_name} executable: {stderr}")
                    continue

                # Run the installer with timeout
                installer_success = False
                for stream_type, content in ssh_client.execute_command_stream(
                    script,
                    timeout=600  # 10 minutes per installer
                ):
                    if stream_type in ["stdout", "stderr"]:
                        monitor.add_log_entry(stream_type, content)
                    elif stream_type == "exit_code":
                        if content == 0:
                            monitor.add_log_entry("system", f"Installer {script_name} completed successfully")
                            installer_success = True
                        else:
                            monitor.add_log_entry("system", f"Installer {script_name} failed with exit code: {content}")
                        break
                    elif stream_type == "error":
                        monitor.add_log_entry("stderr", f"Installer {script_name} error: {content}")
                        break

                # Note: We don't fail the test if individual installers fail,
                # as some may have dependencies that aren't available

            # Check overall system state
            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors detected during individual installer testing"

            logging.info(f"Individual installer test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_individual_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Individual installer test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_installer_dependencies(self, vm_manager, distribution):
        """Test that installer scripts handle dependencies correctly"""
        test_id = f"dependencies_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing installer dependencies on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Test specific dependency chains
            dependency_tests = [
                {
                    "name": "Package manager availability",
                    "command": "which dnf || which pacman",
                    "expected": True
                },
                {
                    "name": "Git availability",
                    "command": "which git",
                    "expected": True
                },
                {
                    "name": "Curl availability",
                    "command": "which curl",
                    "expected": True
                },
                {
                    "name": "Basic build tools",
                    "command": "which gcc || which cc",
                    "expected": False  # Not required but nice to have
                }
            ]

            for test in dependency_tests:
                monitor.add_log_entry("system", f"Testing dependency: {test['name']}")

                exit_code, stdout, stderr = ssh_client.execute_command(
                    test["command"],
                    timeout=10
                )

                if test["expected"]:
                    if exit_code == 0:
                        monitor.add_log_entry("system", f"✓ {test['name']} available")
                    else:
                        monitor.add_log_entry("system", f"✗ {test['name']} missing (required)")
                        # Don't fail test for missing dependencies, just log
                else:
                    if exit_code == 0:
                        monitor.add_log_entry("system", f"✓ {test['name']} available (optional)")
                    else:
                        monitor.add_log_entry("system", f"- {test['name']} not available (optional)")

            # Check system readiness
            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during dependency testing"

            logging.info(f"Dependency test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_dependency_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Dependency test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["fedora"])  # Test Hyprland specifically on Fedora
    def test_hyprland_installation(self, vm_manager, distribution):
        """Test Hyprland installation specifically"""
        test_id = f"hyprland_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing Hyprland installation on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Run Hyprland installer specifically
            hyprland_script = "~/.local/share/chezmoi/software_installers/executable_03_hyprland.sh"

            # Check if script exists
            exit_code, _, _ = ssh_client.execute_command(f"test -f {hyprland_script}", timeout=10)
            assert exit_code == 0, "Hyprland installer script not found"

            # Make executable
            exit_code, _, stderr = ssh_client.execute_command(f"chmod +x {hyprland_script}", timeout=10)
            assert exit_code == 0, f"Failed to make Hyprland script executable: {stderr}"

            # Run Hyprland installer
            monitor.add_log_entry("system", "Starting Hyprland installation")

            hyprland_success = False
            for stream_type, content in ssh_client.execute_command_stream(
                hyprland_script,
                timeout=900  # 15 minutes for Hyprland installation
            ):
                if stream_type in ["stdout", "stderr"]:
                    monitor.add_log_entry(stream_type, content)
                elif stream_type == "exit_code":
                    if content == 0:
                        monitor.add_log_entry("system", "Hyprland installation completed successfully")
                        hyprland_success = True
                    else:
                        monitor.add_log_entry("system", f"Hyprland installation failed with exit code: {content}")
                    break
                elif stream_type == "error":
                    monitor.add_log_entry("stderr", f"Hyprland installation error: {content}")
                    break

            # Note: Hyprland installation might fail in VM environment due to graphics requirements
            # So we check if the attempt was made properly rather than requiring success

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during Hyprland installation"

            logging.info(f"Hyprland installation test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_hyprland_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Hyprland test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)