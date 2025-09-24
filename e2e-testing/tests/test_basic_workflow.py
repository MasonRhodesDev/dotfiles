#!/usr/bin/env python3
"""
Basic Chezmoi Workflow E2E Tests

Tests the fundamental chezmoi init → apply workflow on fresh VMs.
"""

import pytest
import time
import logging
from pathlib import Path

# Import test framework
import sys
sys.path.append(str(Path(__file__).parent.parent / "framework"))
from vm_manager import TestVMManager


class TestBasicWorkflow:
    """Test basic chezmoi workflow on fresh VMs"""

    @pytest.fixture(scope="class")
    def vm_manager(self):
        """Set up VM manager"""
        manager = TestVMManager()
        yield manager
        manager.cleanup_all()

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_chezmoi_init_apply_workflow(self, vm_manager, distribution):
        """Test complete chezmoi init and apply workflow"""
        test_id = f"basic_workflow_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing basic workflow on {vm_name}")

            # Step 1: Install chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"

            # Step 2: Initialize chezmoi repository
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"

            # Step 3: Apply chezmoi configuration
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Step 4: Validate installation
            validation_results = vm_manager.validate_installation(vm_name)
            assert validation_results["chezmoi_status"], "Chezmoi status validation failed"
            assert validation_results["config_files_present"], "Configuration files not found"

            # Step 5: Check for errors in console output
            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors detected during workflow"

            logging.info(f"Basic workflow test passed for {distribution}")

        except Exception as e:
            # Export logs on failure
            if vm_name:
                output_dir = f"test_results/{vm_name}_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Test failed, logs exported to {output_dir}")
            raise

        finally:
            # Clean up VM
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_chezmoi_idempotency(self, vm_manager, distribution):
        """Test that running chezmoi apply multiple times is idempotent"""
        test_id = f"idempotency_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing idempotency on {vm_name}")

            # Install and initialize chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"

            # First apply
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run first chezmoi apply"

            # Second apply (should be idempotent)
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run second chezmoi apply"

            # Third apply (should still be idempotent)
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run third chezmoi apply"

            # Validate no errors occurred
            vm_status = vm_manager.get_vm_status(vm_name)
            assert not vm_status["fatal_errors"], "Fatal errors detected during idempotency test"

            logging.info(f"Idempotency test passed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_idempotency_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Idempotency test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    @pytest.mark.parametrize("distribution", ["arch", "fedora"])
    def test_chezmoi_status_check(self, vm_manager, distribution):
        """Test chezmoi status command functionality"""
        test_id = f"status_check_{int(time.time())}"
        vm_name = None

        try:
            # Create test VM
            vm_info = vm_manager.create_test_vm(distribution, test_id)
            vm_name = vm_info["vm_spec"].name

            logging.info(f"Testing chezmoi status on {vm_name}")

            # Install and initialize chezmoi
            assert vm_manager.install_chezmoi(vm_name), "Failed to install chezmoi"
            assert vm_manager.run_chezmoi_init(vm_name), "Failed to run chezmoi init"

            # Check status before apply (should show differences)
            ssh_client = vm_info["ssh_client"]
            monitor = vm_info["console_monitor"]

            exit_code, stdout, stderr = ssh_client.execute_command("chezmoi status", timeout=30)
            monitor.add_log_entry("system", f"Chezmoi status before apply: exit={exit_code}")
            monitor.add_log_entry("stdout", stdout)

            # Apply configuration
            assert vm_manager.run_chezmoi_apply(vm_name), "Failed to run chezmoi apply"

            # Check status after apply (should show no differences)
            exit_code, stdout, stderr = ssh_client.execute_command("chezmoi status", timeout=30)
            monitor.add_log_entry("system", f"Chezmoi status after apply: exit={exit_code}")
            monitor.add_log_entry("stdout", stdout)

            # Status should return 0 (no differences)
            assert exit_code == 0, f"Chezmoi status returned non-zero exit code: {exit_code}"

            logging.info(f"Status check test passed for {distribution}")

        except Exception as e:
            if vm_name:
                output_dir = f"test_results/{vm_name}_status_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
                logging.error(f"Status check test failed, logs exported to {output_dir}")
            raise

        finally:
            if vm_name:
                vm_manager.cleanup_vm(vm_name)

    def test_parallel_distribution_testing(self, vm_manager):
        """Test running chezmoi on multiple distributions in parallel"""
        distributions = ["arch", "fedora"]
        test_id = f"parallel_{int(time.time())}"
        vm_names = []

        try:
            logging.info("Starting parallel distribution testing")

            # Create VMs for each distribution
            vm_infos = {}
            for dist in distributions:
                vm_info = vm_manager.create_test_vm(dist, f"{test_id}_{dist}")
                vm_name = vm_info["vm_spec"].name
                vm_names.append(vm_name)
                vm_infos[dist] = vm_info

            # Install chezmoi on all VMs
            for dist in distributions:
                vm_name = vm_infos[dist]["vm_spec"].name
                assert vm_manager.install_chezmoi(vm_name), f"Failed to install chezmoi on {dist}"

            # Initialize chezmoi on all VMs
            for dist in distributions:
                vm_name = vm_infos[dist]["vm_spec"].name
                assert vm_manager.run_chezmoi_init(vm_name), f"Failed to init chezmoi on {dist}"

            # Apply chezmoi on all VMs
            for dist in distributions:
                vm_name = vm_infos[dist]["vm_spec"].name
                assert vm_manager.run_chezmoi_apply(vm_name), f"Failed to apply chezmoi on {dist}"

            # Validate all installations
            for dist in distributions:
                vm_name = vm_infos[dist]["vm_spec"].name
                validation_results = vm_manager.validate_installation(vm_name)
                assert validation_results["chezmoi_status"], f"Validation failed on {dist}"

                vm_status = vm_manager.get_vm_status(vm_name)
                assert not vm_status["fatal_errors"], f"Fatal errors on {dist}"

            logging.info("Parallel distribution testing passed")

        except Exception as e:
            # Export logs from all VMs on failure
            for vm_name in vm_names:
                output_dir = f"test_results/{vm_name}_parallel_failure"
                vm_manager.export_vm_logs(vm_name, output_dir)
            logging.error("Parallel testing failed, logs exported")
            raise

        finally:
            # Clean up all VMs
            for vm_name in vm_names:
                vm_manager.cleanup_vm(vm_name)