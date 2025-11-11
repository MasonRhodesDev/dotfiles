# Test Quick Start

## One-Line Commands

```bash
# Run all tests
./tests/run-tests.sh

# Test Fedora only
./tests/run-tests.sh fedora

# Test Arch only
./tests/run-tests.sh arch

# Specific scenario
./tests/run-tests.sh fedora basic-install

# Rebuild containers
./tests/run-tests.sh --no-cache

# Keep containers for debugging
./tests/run-tests.sh --keep
```

## Test Scenarios

| Scenario | Duration | Tests |
|----------|----------|-------|
| basic-install | ~5-10 min | Package installation, state DB, logs |
| state-tracking | ~10-15 min | Re-run skip logic, checksums |
| profile-detection | ~5-10 min | Hostname detection, profile filtering |
| service-validation | ~5-10 min | Service unit files, binaries (Docker, MongoDB) |

## Expected Output

### Success
```
[SUCCESS] Test passed: basic-install on fedora
  Results: tests/results/fedora-basic-install-20251107-123456.log
```

### Failure
```
[ERROR] Test failed: basic-install on fedora
  Results: tests/results/fedora-basic-install-20251107-123456.log
```

## Troubleshooting

### Docker not found
```bash
sudo dnf install docker
sudo systemctl start docker
sudo usermod -aG docker $USER  # then logout/login
```

### Permission denied
```bash
sudo ./tests/run-tests.sh
```

### Container build fails
```bash
# View build logs
docker build -f tests/Dockerfile.fedora -t chezmoi-test-fedora .
```

### Tests hang
```bash
# Set shorter timeout (default 30 min)
TIMEOUT=600 ./tests/run-tests.sh
```

## View Results

```bash
# Latest results
ls -lt tests/results/ | head

# View specific log
cat tests/results/fedora-basic-install-*.log

# Search for errors
grep -i error tests/results/*.log
```

## CI/CD

Tests run automatically on:
- ✓ Push to main
- ✓ Pull requests
- ✓ Manual dispatch

View results: GitHub → Actions → Test Dotfiles
