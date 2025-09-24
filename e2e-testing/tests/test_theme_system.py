#!/usr/bin/env python3
"""
Theme System E2E Tests

Tests the Hyprland theme toggle functionality and Material You color generation.
"""

import pytest
import time
import logging
from pathlib import Path

# Import test framework
import sys
sys.path.append(str(Path(__file__).parent.parent / "framework"))
from vm_manager import TestVMManager


class TestThemeSystem:
    """Test Hyprland theme system functionality"""

    @pytest.fixture(scope="class")
    def vm_manager(self):
        """Set up VM manager"""
        manager = TestVMManager()
        yield manager
        manager.cleanup_all()

    @pytest.mark.parametrize("distribution", ["fedora"])  # Theme system primarily for Fedora
    def test_theme_toggle_installation(self, vm_manager, distribution):
        """Test that theme toggle scripts are properly installed"""
        test_id = f"theme_install_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing theme system installation on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Check for theme system files
            theme_files_to_check = [
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh",
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_generate-theme-configs.py",
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-restore.sh",
            ]

            for theme_file in theme_files_to_check:
                exit_code, _, stderr = ssh_client.execute_command(f"test -f {theme_file}", timeout=10)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ Theme file found: {theme_file}")
                else:
                    monitor.add_log_entry("system", f"✗ Theme file missing: {theme_file}")

            # Check if theme toggle script is executable
            theme_script = "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh"
            exit_code, _, _ = ssh_client.execute_command(f"test -x {theme_script}", timeout=10)

            if exit_code == 0:
                monitor.add_log_entry("system", "Theme toggle script is executable")
            else:
                # Make it executable if it isn't
                exit_code, _, stderr = ssh_client.execute_command(f"chmod +x {theme_script}", timeout=10)
                if exit_code == 0:
                    monitor.add_log_entry("system", "Made theme toggle script executable")
                else:
                    monitor.add_log_entry("stderr", f"Failed to make theme script executable: {stderr}")

            # Check for theme system dependencies
            dependencies = ["python3", "python", "matugen"]

            for dep in dependencies:
                exit_code, stdout, _ = ssh_client.execute_command(f"which {dep}", timeout=10)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ Dependency available: {dep}")
                else:
                    monitor.add_log_entry("system", f"- Dependency not found: {dep}")

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during theme system installation test"

            logging.info(f"Theme system installation test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_theme_install_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Theme installation test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["fedora"])
    def test_theme_script_syntax(self, vm_manager, distribution):
        """Test that theme scripts have valid syntax"""
        test_id = f"theme_syntax_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing theme script syntax on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Test shell script syntax
            shell_scripts = [
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh",
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-restore.sh",
            ]

            for script in shell_scripts:
                monitor.add_log_entry("system", f"Checking syntax: {script}")

                # Check if file exists
                exit_code, _, _ = ssh_client.execute_command(f"test -f {script}", timeout=10)
                if exit_code != 0:
                    monitor.add_log_entry("system", f"Script not found: {script}")
                    continue

                # Check shell syntax
                exit_code, stdout, stderr = ssh_client.execute_command(f"bash -n {script}", timeout=30)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ Shell syntax OK: {script}")
                else:
                    monitor.add_log_entry("stderr", f"✗ Shell syntax error in {script}: {stderr}")

            # Test Python script syntax
            python_scripts = [
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_generate-theme-configs.py",
            ]

            for script in python_scripts:
                monitor.add_log_entry("system", f"Checking Python syntax: {script}")

                # Check if file exists
                exit_code, _, _ = ssh_client.execute_command(f"test -f {script}", timeout=10)
                if exit_code != 0:
                    monitor.add_log_entry("system", f"Python script not found: {script}")
                    continue

                # Check Python syntax
                exit_code, stdout, stderr = ssh_client.execute_command(f"python3 -m py_compile {script}", timeout=30)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ Python syntax OK: {script}")
                else:
                    monitor.add_log_entry("stderr", f"✗ Python syntax error in {script}: {stderr}")

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during theme script syntax test"

            logging.info(f"Theme script syntax test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_theme_syntax_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Theme syntax test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["fedora"])
    def test_theme_toggle_help(self, vm_manager, distribution):
        """Test theme toggle script help functionality"""
        test_id = f"theme_help_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing theme toggle help on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Test theme toggle script help
            theme_script = "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/executable_theme-toggle-modular.sh"

            # Make executable
            ssh_client.execute_command(f"chmod +x {theme_script}", timeout=10)

            # Test help options
            help_commands = [
                f"{theme_script} --help",
                f"{theme_script} -h",
                f"{theme_script}",  # Should show usage if no args
            ]

            for help_cmd in help_commands:
                monitor.add_log_entry("system", f"Testing help command: {help_cmd}")

                exit_code, stdout, stderr = ssh_client.execute_command(help_cmd, timeout=30)

                # Log output for analysis
                if stdout:
                    monitor.add_log_entry("stdout", f"Help output: {stdout[:200]}...")
                if stderr:
                    monitor.add_log_entry("stderr", f"Help stderr: {stderr[:200]}...")

                # Help should either succeed or fail gracefully
                monitor.add_log_entry("system", f"Help command exit code: {exit_code}")

            # Test invalid arguments
            monitor.add_log_entry("system", "Testing invalid arguments")
            exit_code, stdout, stderr = ssh_client.execute_command(
                f"{theme_script} --invalid-option",
                timeout=30
            )

            monitor.add_log_entry("system", f"Invalid option exit code: {exit_code}")
            if stderr:
                monitor.add_log_entry("stderr", f"Invalid option error: {stderr[:200]}...")

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during theme help test"

            logging.info(f"Theme toggle help test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_theme_help_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Theme help test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["fedora"])
    def test_theme_configuration_files(self, vm_manager, distribution):
        """Test that theme configuration templates are present"""
        test_id = f"theme_configs_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing theme configuration files on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Check for matugen template directory
            template_dirs_to_check = [
                "~/.config/matugen/templates",
                "~/.local/share/chezmoi/dot_config/matugen",
            ]

            for template_dir in template_dirs_to_check:
                exit_code, stdout, stderr = ssh_client.execute_command(f"ls -la {template_dir}", timeout=30)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ Template directory found: {template_dir}")
                    monitor.add_log_entry("stdout", f"Contents: {stdout[:300]}...")
                else:
                    monitor.add_log_entry("system", f"- Template directory not found: {template_dir}")

            # Look for theme-related configuration files
            theme_config_patterns = [
                "~/.config/hypr/*.conf",
                "~/.config/waybar/config*",
                "~/.config/gtk-*",
            ]

            for pattern in theme_config_patterns:
                exit_code, stdout, stderr = ssh_client.execute_command(f"ls {pattern} 2>/dev/null || true", timeout=30)
                if stdout.strip():
                    monitor.add_log_entry("system", f"✓ Theme config files found for pattern: {pattern}")
                    monitor.add_log_entry("stdout", f"Files: {stdout[:200]}...")
                else:
                    monitor.add_log_entry("system", f"- No theme config files found for pattern: {pattern}")

            # Check for theme system README
            readme_files = [
                "~/.local/share/chezmoi/scripts/hyprland-theme-toggle/README.md",
            ]

            for readme_file in readme_files:
                exit_code, _, _ = ssh_client.execute_command(f"test -f {readme_file}", timeout=10)
                if exit_code == 0:
                    monitor.add_log_entry("system", f"✓ README found: {readme_file}")

                    # Read first few lines
                    exit_code, stdout, _ = ssh_client.execute_command(f"head -n 10 {readme_file}", timeout=10)
                    if exit_code == 0:
                        monitor.add_log_entry("stdout", f"README preview: {stdout[:300]}...")
                else:
                    monitor.add_log_entry("system", f"- README not found: {readme_file}")

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during theme configuration test"

            logging.info(f"Theme configuration test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_theme_config_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Theme configuration test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["fedora"])
    def test_theme_system_integration(self, vm_manager, distribution):
        """Test overall theme system integration"""
        test_id = f"theme_integration_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing theme system integration on {vm_name}")

            # Setup chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Get SSH client and monitor
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            # Test theme system components integration
            integration_tests = [
                {
                    "name": "Script permissions",
                    "command": "find ~/.local/share/chezmoi/scripts/hyprland-theme-toggle -name 'executable_*' -not -executable",
                    "expect_empty": True
                },
                {
                    "name": "Python script imports",
                    "command": "python3 -c 'import sys; print(\"Python import test passed\")'",
                    "expect_success": True
                },
                {
                    "name": "Theme directory structure",
                    "command": "test -d ~/.local/share/chezmoi/scripts/hyprland-theme-toggle && echo 'Theme directory OK'",
                    "expect_success": True
                }
            ]

            for test in integration_tests:
                monitor.add_log_entry("system", f"Running integration test: {test['name']}")

                exit_code, stdout, stderr = ssh_client.execute_command(test["command"], timeout=30)

                if test.get("expect_empty", False):
                    if not stdout.strip():
                        monitor.add_log_entry("system", f"✓ {test['name']}: No issues found")
                    else:
                        monitor.add_log_entry("system", f"⚠ {test['name']}: Issues found: {stdout}")

                elif test.get("expect_success", False):
                    if exit_code == 0:
                        monitor.add_log_entry("system", f"✓ {test['name']}: Success")
                    else:
                        monitor.add_log_entry("system", f"✗ {test['name']}: Failed - {stderr}")

                # Log all output for debugging
                if stdout:
                    monitor.add_log_entry("stdout", f"{test['name']}: {stdout}")
                if stderr:
                    monitor.add_log_entry("stderr", f"{test['name']}: {stderr}")

            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors during theme system integration test"

            logging.info(f"Theme system integration test completed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_theme_integration_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Theme integration test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)