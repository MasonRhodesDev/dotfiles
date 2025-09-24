# Chezmoi E2E Testing Makefile

.PHONY: help install build-images test test-basic test-software test-theme test-parallel clean clean-vms clean-images clean-all

# Default target
help:
	@echo "Chezmoi E2E Testing"
	@echo ""
	@echo "Available targets:"
	@echo "  install        - Install all dependencies (Python + system)"
	@echo "  install-python - Install Python dependencies only"
	@echo "  install-packer-only - Install Packer only"
	@echo "  check-deps     - Check dependency availability"
	@echo "  build-images   - Build base VM images with Packer"
	@echo "  test           - Run all E2E tests"
	@echo "  test-basic     - Run basic workflow tests only"
	@echo "  test-software  - Run software installation tests only"
	@echo "  test-theme     - Run theme system tests only"
	@echo "  test-parallel  - Run tests in parallel"
	@echo "  test-arch      - Run tests on Arch Linux only"
	@echo "  test-fedora    - Run tests on Fedora only"
	@echo "  clean          - Clean test results and logs"
	@echo "  clean-vms      - Clean up running VMs"
	@echo "  clean-images   - Clean base VM images"
	@echo "  clean-all      - Clean everything"
	@echo ""
	@echo "Environment variables:"
	@echo "  TEST_TIMEOUT   - Test timeout in seconds (default: 1800)"
	@echo "  VM_MEMORY      - VM memory in MB (default: 4096)"
	@echo "  VM_CPUS        - VM CPU cores (default: 2)"
	@echo "  KEEP_VMS       - Keep VMs after tests (default: false)"

# Installation
install: check-deps install-python install-system-deps
	@echo "All dependencies installed and validated"

install-python:
	pip install -r requirements.txt
	@echo "Python dependencies installed"

install-system-deps:
	@echo "Checking and installing system dependencies..."
	@if ! which packer > /dev/null 2>&1; then \
		echo "Installing Packer..."; \
		if which dnf > /dev/null 2>&1; then \
			sudo dnf install -y packer; \
		elif which pacman > /dev/null 2>&1; then \
			sudo pacman -S --noconfirm packer; \
		elif which apt > /dev/null 2>&1; then \
			curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - && \
			sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
			sudo apt-get update && sudo apt-get install packer; \
		else \
			echo "Please install Packer manually: https://www.packer.io/downloads"; \
			exit 1; \
		fi; \
	fi
	@if ! which qemu-system-x86_64 > /dev/null 2>&1; then \
		echo "Installing QEMU..."; \
		if which dnf > /dev/null 2>&1; then \
			sudo dnf install -y qemu-kvm qemu-system-x86_64; \
		elif which pacman > /dev/null 2>&1; then \
			sudo pacman -S --noconfirm qemu-system-x86_64; \
		elif which apt > /dev/null 2>&1; then \
			sudo apt-get install -y qemu-kvm qemu-system-x86_64; \
		fi; \
	fi
	@if ! which genisoimage > /dev/null 2>&1; then \
		echo "Installing genisoimage..."; \
		if which dnf > /dev/null 2>&1; then \
			sudo dnf install -y genisoimage; \
		elif which pacman > /dev/null 2>&1; then \
			sudo pacman -S --noconfirm cdrtools; \
		elif which apt > /dev/null 2>&1; then \
			sudo apt-get install -y genisoimage; \
		fi; \
	fi
	@echo "System dependencies validated"

install-packer-only:
	@echo "Installing Packer..."
	@if which dnf > /dev/null 2>&1; then \
		sudo dnf install -y packer; \
	elif which pacman > /dev/null 2>&1; then \
		sudo pacman -S --noconfirm packer; \
	elif which apt > /dev/null 2>&1; then \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - && \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" && \
		sudo apt-get update && sudo apt-get install packer; \
	else \
		echo "Unsupported package manager. Please install Packer manually: https://www.packer.io/downloads"; \
		exit 1; \
	fi
	@echo "Packer installed"

# Build VM images
build-images: clean-images
	./infrastructure/build_base_images.sh
	@echo "Base VM images built"

build-images-arch:
	./infrastructure/build_base_images.sh --arch-only
	@echo "Arch Linux base image built"

build-images-fedora:
	./infrastructure/build_base_images.sh --fedora-only
	@echo "Fedora base image built"

# Build Arch only for testing
build-arch-test: clean-images
	./infrastructure/build_base_images.sh --arch-only

# Simple debug - just run archinstall and watch
debug-archinstall: clean-images
	@echo "Starting simple archinstall debug - VNC at localhost:5902"
	@echo "Connect with VNC viewer to watch archinstall run"
	cd infrastructure/packer && packer init arch-debug-simple.pkr.hcl && PACKER_LOG=1 packer build -force arch-debug-simple.pkr.hcl

# Test execution
test:
	python run_tests.py --verbose

test-basic:
	python run_tests.py --test-type basic --verbose

test-software:
	python run_tests.py --test-type software --verbose

test-theme:
	python run_tests.py --test-type theme --verbose

test-parallel:
	python run_tests.py --parallel --verbose

test-arch:
	python run_tests.py --distribution arch --verbose

test-fedora:
	python run_tests.py --distribution fedora --verbose

# Full test cycle with image building
test-full:
	python run_tests.py --build-images --verbose

# Test with debugging (keep VMs)
test-debug:
	python run_tests.py --keep-vms --verbose

# Quick smoke test
test-smoke:
	python run_tests.py tests/test_basic_workflow.py::TestBasicWorkflow::test_chezmoi_init_apply_workflow --verbose

# Cleanup
clean:
	rm -rf test_results/
	rm -rf __pycache__/
	find . -name "*.pyc" -delete
	find . -name "*.pyo" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "Test results and cache cleaned"

clean-vms:
	python -c "from framework.vm_manager import TestVMManager; TestVMManager().cleanup_all()"
	@echo "VMs cleaned up"

clean-images:
	rm -rf infrastructure/images/
	rm -rf infrastructure/temp/
	@echo "VM images cleaned"

clean-all: clean clean-vms clean-images
	@echo "Everything cleaned"

# Development helpers
lint:
	python -m flake8 framework/ tests/ reporting/ --max-line-length=100 --ignore=E501,W503
	@echo "Linting completed"

format:
	python -m black framework/ tests/ reporting/ run_tests.py
	@echo "Code formatted"

check-deps:
	@echo "Checking dependencies..."
	@which python3 > /dev/null || (echo "ERROR: Python3 not found - please install Python 3" && exit 1)
	@echo "✓ Python3 available"
	@if which qemu-system-x86_64 > /dev/null 2>&1; then echo "✓ QEMU available"; else echo "⚠ QEMU not found - will attempt to install"; fi
	@if which packer > /dev/null 2>&1; then echo "✓ Packer available"; else echo "⚠ Packer not found - will attempt to install"; fi
	@if which genisoimage > /dev/null 2>&1; then echo "✓ genisoimage available"; else echo "⚠ genisoimage not found - will attempt to install"; fi
	@if [ -c /dev/kvm ]; then echo "✓ KVM acceleration available"; else echo "⚠ KVM acceleration not available - tests will run slower"; fi
	@echo "Dependency check completed"

# CI/CD targets
ci-test:
	python run_tests.py --junit-xml test_results/junit.xml --html-report test_results/report.html

ci-build:
	make build-images

# Documentation
docs:
	@echo "Generating documentation..."
	@echo "See README.md for usage instructions"
	@echo "Test results available in test_results/ after running tests"

# Status
status:
	@echo "E2E Testing Framework Status:"
	@echo "  Framework directory: $(shell pwd)"
	@echo "  Python version: $(shell python3 --version)"
	@echo "  QEMU available: $(shell which qemu-system-x86_64 > /dev/null && echo 'Yes' || echo 'No')"
	@echo "  Packer available: $(shell which packer > /dev/null && echo 'Yes' || echo 'No')"
	@echo "  Base images: $(shell ls infrastructure/images/base/ 2>/dev/null | wc -l) files"
	@echo "  Test results: $(shell ls test_results/ 2>/dev/null | wc -l) files"

# Interactive mode
interactive:
	@echo "Starting interactive E2E testing session..."
	@echo "Available commands:"
	@echo "  - make test           # Run all tests"
	@echo "  - make test-basic     # Run basic tests"
	@echo "  - make test-debug     # Run with VMs kept for debugging"
	@echo "  - make clean-vms      # Clean up VMs"
	@echo "  - make status         # Show status"
	@bash