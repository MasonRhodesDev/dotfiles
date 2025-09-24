#!/usr/bin/env python3
"""
E2E Test Runner

Main entry point for running chezmoi E2E tests with QEMU VMs.
"""

import os
import sys
import argparse
import subprocess
import logging
import time
from pathlib import Path
from typing import List, Optional

# Add framework to path
sys.path.append(str(Path(__file__).parent / "framework"))
from vm_manager import TestVMManager
from reporting.generator import TestReportGenerator


def setup_logging(verbose: bool = False) -> None:
    """Set up logging configuration"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s [%(levelname)8s] %(name)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def check_prerequisites() -> bool:
    """Check if all prerequisites are available"""
    logger = logging.getLogger("prerequisites")

    required_commands = [
        ("python3", "Python 3 interpreter"),
        ("qemu-system-x86_64", "QEMU x86_64 emulator"),
        ("packer", "Packer for building VM images"),
        ("genisoimage", "ISO creation tool for cloud-init"),
    ]

    missing = []
    for cmd, description in required_commands:
        if not subprocess.run(["which", cmd], capture_output=True).returncode == 0:
            missing.append((cmd, description))

    if missing:
        logger.error("Missing prerequisites:")
        for cmd, desc in missing:
            logger.error(f"  - {cmd}: {desc}")
        return False

    # Check if KVM is available
    if os.path.exists("/dev/kvm"):
        logger.info("KVM acceleration available")
    else:
        logger.warning("KVM acceleration not available - tests will run slower")

    # Check base images
    base_images_dir = Path(__file__).parent / "infrastructure" / "images" / "base"
    if not base_images_dir.exists():
        logger.warning("Base images directory not found - will need to build images")

    return True


def build_base_images(distributions: List[str] = None) -> bool:
    """Build base VM images using Packer"""
    logger = logging.getLogger("image_builder")

    script_path = Path(__file__).parent / "infrastructure" / "build_base_images.sh"

    if not script_path.exists():
        logger.error(f"Build script not found: {script_path}")
        return False

    logger.info("Building base VM images...")

    cmd = [str(script_path)]
    if distributions:
        if "arch" in distributions and "fedora" not in distributions:
            cmd.append("--arch-only")
        elif "fedora" in distributions and "arch" not in distributions:
            cmd.append("--fedora-only")

    try:
        result = subprocess.run(cmd, check=True, text=True, capture_output=True)
        logger.info("Base images built successfully")
        return True
    except subprocess.CalledProcessError as e:
        logger.error(f"Failed to build base images: {e}")
        if e.stdout:
            logger.error(f"Stdout: {e.stdout}")
        if e.stderr:
            logger.error(f"Stderr: {e.stderr}")
        return False


def run_pytest(args: List[str]) -> int:
    """Run pytest with given arguments"""
    logger = logging.getLogger("pytest_runner")

    # Ensure test results directory exists
    results_dir = Path("test_results")
    results_dir.mkdir(exist_ok=True)

    # Build pytest command
    pytest_cmd = ["python", "-m", "pytest"] + args

    logger.info(f"Running pytest: {' '.join(pytest_cmd)}")

    try:
        result = subprocess.run(pytest_cmd, text=True)
        return result.returncode
    except KeyboardInterrupt:
        logger.warning("Test run interrupted by user")
        return 130
    except Exception as e:
        logger.error(f"Error running pytest: {e}")
        return 1


def cleanup_vms() -> None:
    """Clean up any remaining VMs"""
    logger = logging.getLogger("cleanup")
    logger.info("Cleaning up VMs...")

    try:
        manager = TestVMManager()
        manager.cleanup_all()
        logger.info("VM cleanup completed")
    except Exception as e:
        logger.error(f"Error during VM cleanup: {e}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Chezmoi E2E Test Runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all tests
  python run_tests.py

  # Run only basic workflow tests
  python run_tests.py --test-type basic

  # Test only Fedora
  python run_tests.py --distribution fedora

  # Build images and run tests
  python run_tests.py --build-images

  # Run tests with verbose output
  python run_tests.py --verbose

  # Keep VMs running for debugging
  python run_tests.py --keep-vms

  # Run specific test file
  python run_tests.py tests/test_basic_workflow.py
        """
    )

    parser.add_argument(
        "--build-images",
        action="store_true",
        help="Build base VM images before running tests"
    )

    parser.add_argument(
        "--distribution",
        choices=["arch", "fedora"],
        action="append",
        dest="distributions",
        help="Specify distributions to test (can be used multiple times)"
    )

    parser.add_argument(
        "--test-type",
        choices=["basic", "software", "theme", "integration"],
        help="Run specific type of tests"
    )

    parser.add_argument(
        "--parallel",
        action="store_true",
        help="Run tests in parallel (requires pytest-xdist)"
    )

    parser.add_argument(
        "--keep-vms",
        action="store_true",
        help="Keep VMs running after tests for debugging"
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    parser.add_argument(
        "--html-report",
        default="test_results/report.html",
        help="HTML report output path"
    )

    parser.add_argument(
        "--junit-xml",
        help="JUnit XML report output path"
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=1800,
        help="Test timeout in seconds (default: 1800)"
    )

    parser.add_argument(
        "test_paths",
        nargs="*",
        help="Specific test files or directories to run"
    )

    args = parser.parse_args()

    # Set up logging
    setup_logging(args.verbose)
    logger = logging.getLogger("main")

    logger.info("Starting Chezmoi E2E Test Runner")

    # Check prerequisites
    if not check_prerequisites():
        logger.error("Prerequisites check failed")
        return 1

    # Build images if requested
    if args.build_images:
        if not build_base_images(args.distributions):
            logger.error("Image building failed")
            return 1

    try:
        # Build pytest arguments
        pytest_args = []

        # Add test paths
        if args.test_paths:
            pytest_args.extend(args.test_paths)

        # Add distribution filter
        if args.distributions:
            for dist in args.distributions:
                pytest_args.extend(["--distribution", dist])

        # Add test type marker
        if args.test_type:
            pytest_args.extend(["-m", args.test_type])

        # Add parallel execution
        if args.parallel:
            pytest_args.extend(["-n", "auto"])

        # Add VM options
        if args.keep_vms:
            pytest_args.append("--keep-vms")

        pytest_args.extend(["--test-timeout", str(args.timeout)])

        # Add reporting options
        if args.html_report:
            pytest_args.extend(["--html", args.html_report, "--self-contained-html"])

        if args.junit_xml:
            pytest_args.extend(["--junit-xml", args.junit_xml])

        # Add verbosity
        if args.verbose:
            pytest_args.append("-v")

        # Run tests
        exit_code = run_pytest(pytest_args)

        if exit_code == 0:
            logger.info("All tests passed!")
        else:
            logger.warning(f"Tests completed with exit code: {exit_code}")

        return exit_code

    except KeyboardInterrupt:
        logger.warning("Test run interrupted")
        return 130

    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return 1

    finally:
        # Always clean up unless requested to keep VMs
        if not args.keep_vms:
            cleanup_vms()


if __name__ == "__main__":
    sys.exit(main())