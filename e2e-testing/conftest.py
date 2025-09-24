#!/usr/bin/env python3
"""
Pytest configuration and fixtures for E2E testing.
"""

import os
import sys
import time
import logging
import pytest
from pathlib import Path

# Add framework to Python path
sys.path.append(str(Path(__file__).parent / "framework"))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)8s] %(name)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)


def pytest_addoption(parser):
    """Add custom command-line options"""
    parser.addoption(
        "--distribution",
        action="append",
        default=[],
        help="Specify distributions to test (arch, fedora). Can be used multiple times."
    )
    parser.addoption(
        "--skip-vm-build",
        action="store_true",
        default=False,
        help="Skip building base VM images"
    )
    parser.addoption(
        "--keep-vms",
        action="store_true",
        default=False,
        help="Keep VMs running after tests for debugging"
    )
    parser.addoption(
        "--test-timeout",
        type=int,
        default=1800,
        help="Timeout for individual tests in seconds (default: 1800)"
    )
    parser.addoption(
        "--vm-memory",
        type=int,
        default=4096,
        help="VM memory in MB (default: 4096)"
    )
    parser.addoption(
        "--vm-cpus",
        type=int,
        default=2,
        help="VM CPU cores (default: 2)"
    )


def pytest_configure(config):
    """Configure pytest"""
    # Create test results directory
    results_dir = Path("test_results")
    results_dir.mkdir(exist_ok=True)

    # Store config options
    config.e2e_options = {
        'distributions': config.getoption("--distribution"),
        'skip_vm_build': config.getoption("--skip-vm-build"),
        'keep_vms': config.getoption("--keep-vms"),
        'test_timeout': config.getoption("--test-timeout"),
        'vm_memory': config.getoption("--vm-memory"),
        'vm_cpus': config.getoption("--vm-cpus"),
    }


def pytest_collection_modifyitems(config, items):
    """Modify test collection based on options"""
    # Filter by distribution if specified
    distributions = config.e2e_options['distributions']
    if distributions:
        selected_items = []
        for item in items:
            # Check if test has distribution parameter
            if hasattr(item, 'callspec') and 'distribution' in item.callspec.params:
                if item.callspec.params['distribution'] in distributions:
                    selected_items.append(item)
            else:
                # Keep tests without distribution parameter
                selected_items.append(item)
        items[:] = selected_items

    # Add timeout marker to all tests
    timeout = config.e2e_options['test_timeout']
    for item in items:
        item.add_marker(pytest.mark.timeout(timeout))


def pytest_sessionstart(session):
    """Called before test session starts"""
    config = session.config
    logger = logging.getLogger("pytest_session")

    logger.info("Starting E2E test session")
    logger.info(f"Test options: {config.e2e_options}")

    # Check prerequisites
    if not config.e2e_options['skip_vm_build']:
        logger.info("Checking VM base images...")
        # TODO: Add base image validation


def pytest_sessionfinish(session, exitstatus):
    """Called after test session finishes"""
    logger = logging.getLogger("pytest_session")
    logger.info(f"E2E test session finished with exit status: {exitstatus}")


@pytest.fixture(scope="session")
def e2e_config(request):
    """Provide E2E test configuration"""
    return request.config.e2e_options


@pytest.fixture(scope="session")
def test_results_dir():
    """Provide test results directory"""
    results_dir = Path("test_results")
    results_dir.mkdir(exist_ok=True)
    return results_dir


@pytest.fixture
def test_id():
    """Generate unique test ID"""
    return f"test_{int(time.time())}_{os.getpid()}"


@pytest.fixture
def vm_cleanup_list(request):
    """Track VMs for cleanup"""
    cleanup_list = []

    def add_vm(vm_name):
        cleanup_list.append(vm_name)

    def cleanup_all():
        if not request.config.e2e_options['keep_vms']:
            # Import here to avoid circular imports
            from vm_manager import TestVMManager
            manager = TestVMManager()
            for vm_name in cleanup_list:
                try:
                    manager.cleanup_vm(vm_name)
                except Exception as e:
                    logging.error(f"Failed to cleanup VM {vm_name}: {e}")

    # Add cleanup function
    add_vm.cleanup_all = cleanup_all

    # Register cleanup
    request.addfinalizer(cleanup_all)

    return add_vm


@pytest.fixture(autouse=True)
def test_logging(request):
    """Set up per-test logging"""
    test_name = request.node.name
    logger = logging.getLogger(f"test.{test_name}")

    logger.info(f"Starting test: {test_name}")

    def log_test_end():
        logger.info(f"Finished test: {test_name}")

    request.addfinalizer(log_test_end)
    return logger


# Custom markers
pytestmark = [
    pytest.mark.filterwarnings("ignore:unclosed.*:ResourceWarning"),
    pytest.mark.filterwarnings("ignore:.*deprecated.*:DeprecationWarning"),
]


# Pytest hooks for better error reporting
def pytest_runtest_makereport(item, call):
    """Customize test reporting"""
    if call.when == "call" and call.excinfo is not None:
        # Add VM information to failure reports
        if hasattr(item, 'callspec') and 'distribution' in item.callspec.params:
            distribution = item.callspec.params['distribution']
            call.excinfo.value.args = (
                f"{call.excinfo.value.args[0]} (Distribution: {distribution})",
            ) + call.excinfo.value.args[1:]


# Helper functions for tests
def pytest_namespace():
    """Add helpers to pytest namespace"""
    return {
        'e2e_helpers': {
            'wait_for_condition': wait_for_condition,
            'retry_on_failure': retry_on_failure,
        }
    }


def wait_for_condition(condition_func, timeout=60, interval=2, description="condition"):
    """Wait for a condition to become true"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            if condition_func():
                return True
        except Exception:
            pass
        time.sleep(interval)
    raise TimeoutError(f"Timeout waiting for {description} after {timeout} seconds")


def retry_on_failure(func, max_retries=3, delay=1, exceptions=(Exception,)):
    """Retry a function on failure"""
    for attempt in range(max_retries + 1):
        try:
            return func()
        except exceptions as e:
            if attempt == max_retries:
                raise
            logging.warning(f"Attempt {attempt + 1} failed: {e}. Retrying in {delay}s...")
            time.sleep(delay)
            delay *= 2  # Exponential backoff