# Chezmoi E2E Testing Framework

Automated end-to-end testing of chezmoi dotfiles using QEMU virtual machines for Arch Linux and Fedora.

## Architecture

```
e2e-testing/
├── infrastructure/          # VM provisioning and management
│   ├── packer/             # Base image templates
│   ├── qemu/               # VM lifecycle scripts
│   └── cloud-init/         # User setup configurations
├── framework/              # Test execution framework
│   ├── vm_manager.py       # VM lifecycle management
│   ├── test_runner.py      # Main test orchestrator
│   ├── console_monitor.py  # Output capture and error detection
│   └── ssh_client.py       # Remote command execution
├── tests/                  # Test scenarios
│   ├── test_basic_workflow.py
│   ├── test_software_install.py
│   └── test_theme_system.py
├── reporting/              # Results and artifacts
│   ├── generator.py        # Report generation
│   └── templates/          # HTML report templates
└── config/                 # Configuration files
    ├── test_config.yaml    # Test parameters
    └── vm_config.yaml      # VM specifications
```

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Build base images (one-time setup)
./infrastructure/build_base_images.sh

# Run tests
python -m pytest tests/ -v --html=report.html
```

## Features

- **Multi-distribution testing**: Parallel validation on Arch and Fedora
- **Fresh VM per test**: Ensures clean state and reproducible results
- **Real-time monitoring**: Console output capture with error detection
- **Comprehensive reporting**: HTML reports with logs and screenshots
- **Configurable timeouts**: Handle long-running operations gracefully

## Test Flow

1. **Provision**: Create fresh QEMU VMs from base images
2. **Bootstrap**: Set up test user with sudo access
3. **Install**: Deploy chezmoi via package managers
4. **Execute**: Run `chezmoi init` and `chezmoi apply`
5. **Validate**: Verify configurations and installed software
6. **Report**: Collect artifacts and generate detailed reports

## Configuration

Edit `config/test_config.yaml` to customize:
- Test timeouts and retry counts
- VM resource allocation
- Chezmoi repository URL
- Test scenarios to run