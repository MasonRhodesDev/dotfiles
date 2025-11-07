# Automated Testing for Chezmoi Dotfiles

This directory contains automated tests for the collision-free installation system.

## Architecture

Tests run in Docker containers to simulate fresh system installations:
- **Fedora 41 container**: Tests work profile and Fedora-specific packages
- **Arch Linux container**: Tests personal profile and Arch-specific packages

## Limitations

Docker containers have some limitations compared to full VMs:
- ⚠️ **No systemd**: Services can't be started (docker, mongod, etc.)
- ⚠️ **Limited init system**: No service management testing
- ✅ **Package installation**: DNF, pacman, cargo, flatpak work
- ✅ **File operations**: All file-based tests work
- ✅ **State tracking**: JSON database operations work
- ✅ **Collision detection**: Package queries work

## Quick Start

```bash
# Run all tests
./tests/run-tests.sh

# Run specific distribution
./tests/run-tests.sh fedora
./tests/run-tests.sh arch

# Run specific test scenario
./tests/run-tests.sh fedora basic-install
```

## Test Scenarios

1. **basic-install**: Verify packages install without errors
2. **state-tracking**: Verify re-runs skip already installed packages
3. **collision-detection**: Verify conflicts are detected
4. **error-recovery**: Verify failures don't block other categories
5. **profile-switching**: Verify profile-based installation

## CI/CD Integration

Tests run automatically on:
- Pull requests to main
- Pushes to main
- Manual workflow dispatch

See `.github/workflows/test-dotfiles.yml` for configuration.

## Running Tests Locally

### Prerequisites

```bash
# Docker or Podman
sudo dnf install docker  # or podman
sudo systemctl enable --now docker
sudo usermod -aG docker $USER  # logout/login required
```

### Run Tests

```bash
# From repo root
cd ~/.local/share/chezmoi
./tests/run-tests.sh
```

### View Results

```bash
# Test results saved to tests/results/
cat tests/results/fedora-latest.log
cat tests/results/arch-latest.log
```

## Test Structure

```
tests/
├── README.md                    # This file
├── Dockerfile.fedora            # Fedora 41 test container
├── Dockerfile.arch              # Arch Linux test container
├── run-tests.sh                 # Main test runner
├── scenarios/                   # Test scenarios
│   ├── basic-install.sh
│   ├── state-tracking.sh
│   ├── collision-detection.sh
│   ├── error-recovery.sh
│   └── profile-switching.sh
└── results/                     # Test output (gitignored)
    ├── fedora-latest.log
    └── arch-latest.log
```

## Writing New Tests

Create a new scenario in `tests/scenarios/`:

```bash
#!/bin/bash
# tests/scenarios/my-test.sh
set -euo pipefail

echo "=== My Test Scenario ==="

# Your test logic here
chezmoi apply

# Verify results
if [ -f ~/.local/state/chezmoi-installs/state.db.json ]; then
    echo "✓ State DB created"
else
    echo "✗ State DB missing"
    exit 1
fi
```

## Known Issues

### Systemd Services
Docker containers can't start systemd services. Tests that check service status will show warnings but should not fail.

**Expected warnings:**
```
⚠ mongod is enabled but not running
⚠ docker is enabled but not running
```

### AUR Packages (Arch)
AUR packages require building from source and may be slow. Consider using `--noconfirm` and `--needed` flags.

### Network Timeouts
Container networking can be slower than host. Retry logic should handle this, but some tests may take longer.

## Troubleshooting

### Tests Fail to Start
```bash
# Check Docker is running
systemctl status docker

# Check you're in docker group
groups | grep docker
```

### Permission Errors
```bash
# Run with sudo if not in docker group
sudo ./tests/run-tests.sh
```

### Container Build Fails
```bash
# Build manually to see errors
docker build -f tests/Dockerfile.fedora -t chezmoi-test-fedora .
```

### Tests Hang
```bash
# Set timeout (default 30 minutes)
TIMEOUT=600 ./tests/run-tests.sh
```

## Maintenance

### Update Base Images
```bash
# Pull latest images
docker pull fedora:41
docker pull archlinux:latest

# Rebuild test containers
docker build --no-cache -f tests/Dockerfile.fedora -t chezmoi-test-fedora .
docker build --no-cache -f tests/Dockerfile.arch -t chezmoi-test-arch .
```

### Clean Up
```bash
# Remove test containers
docker ps -a | grep chezmoi-test | awk '{print $1}' | xargs docker rm

# Remove test images
docker images | grep chezmoi-test | awk '{print $3}' | xargs docker rmi
```
