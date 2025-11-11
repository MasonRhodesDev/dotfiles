# VM Testing Workflow

This document describes when and how to perform comprehensive VM testing with real systemd services.

## When to Run VM Tests

✅ **Required Before:**
- Merging to main branch
- Major releases (quarterly)
- Changes to service configuration (docker, mongodb)
- Changes to systemd-related code

⚠️ **Consider Running After:**
- Adding new services to packages.toml
- Modifying enable_services() function
- Changes to post-install scripts
- Platform-specific package updates

❌ **Not Needed For:**
- Documentation changes
- Non-service package additions
- Template-only changes
- Configuration file updates (without service impact)

## Quick VM Test (30 minutes)

For rapid validation before merging:

### 1. Create Test VM

```bash
# Using libvirt/KVM
virt-install \
  --name chezmoi-test-fedora \
  --memory 4096 \
  --vcpus 2 \
  --disk size=20 \
  --cdrom ~/Downloads/Fedora-Workstation-Live-x86_64-41.iso \
  --os-variant fedora41
```

### 2. Set Up VM

```bash
# SSH into VM (or use console)
ssh mason@chezmoi-test-fedora

# Set hostname for work profile
sudo hostnamectl set-hostname mason-work-test

# Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# Initialize with test branch
chezmoi init --apply --branch refactor/collision-free-installers <your-repo>
```

### 3. Verify Services

```bash
# Check Docker
sudo systemctl status docker
docker --version
docker ps  # Should work without sudo after logout/login

# Check MongoDB
sudo systemctl status mongod  # Fedora
sudo systemctl status mongodb # Arch
mongosh --version
mongosh --eval "db.version()"  # Test connection

# Check logs
tail -50 ~/.cache/dotfiles-install/system-*.log
tail -50 ~/.cache/dotfiles-install/profile-work-*.log
```

### 4. Document Results

```bash
# Capture evidence
systemctl status docker > ~/docker-status.txt
systemctl status mongod > ~/mongod-status.txt
docker ps -a >> ~/docker-status.txt
mongosh --eval "db.serverStatus()" > ~/mongo-status.txt

# Copy logs off VM
scp mason@chezmoi-test-fedora:~/*.txt ~/vm-test-results/
scp -r mason@chezmoi-test-fedora:~/.cache/dotfiles-install ~/vm-test-results/logs/
```

## Comprehensive VM Test (2-3 hours)

For thorough validation before major releases:

### Test Matrix

| VM | OS | Profile | Services to Verify |
|----|----|---------|--------------------|
| vm-fedora-work | Fedora 41 | work | docker, containerd, mongod |
| vm-arch-personal | Arch Linux | personal | (none - personal has no services) |
| vm-fedora-personal | Fedora 41 | personal | (none) |
| vm-arch-work | Arch Linux | work | docker, containerd, mongodb |

### Service Test Checklist

For each VM with services:

#### Docker Service Tests

- [ ] `systemctl status docker` - Shows active (running)
- [ ] `systemctl is-enabled docker` - Shows enabled
- [ ] `docker --version` - Displays version
- [ ] `docker ps` - Lists containers (should work without sudo after logout)
- [ ] `docker run hello-world` - Pulls and runs test container
- [ ] `docker-compose --version` - Displays version
- [ ] Service survives reboot: `sudo reboot` → verify after reboot

#### MongoDB Service Tests

- [ ] `systemctl status mongod` (Fedora) or `mongodb` (Arch) - Shows active
- [ ] `systemctl is-enabled mongod/mongodb` - Shows enabled
- [ ] `mongod --version` - Displays version
- [ ] `mongosh --version` - Displays shell version
- [ ] `mongosh --eval "db.version()"` - Connects and queries version
- [ ] `mongosh --eval "rs.status()"` - Replica set initialized
- [ ] Service listens on port: `ss -tlnp | grep 27017`
- [ ] Service survives reboot: `sudo reboot` → verify after reboot

#### Installation Flow Tests

- [ ] System packages install without errors
- [ ] User packages install without sudo prompts
- [ ] Profile-specific packages install correctly
- [ ] Services start automatically after installation
- [ ] Services persist after reboot
- [ ] Logs show no critical errors
- [ ] State DB created at ~/.local/state/chezmoi-installs/state.db.json
- [ ] Final report shows success for service categories

### Test Script Template

Save as `test-services.sh` on VM:

```bash
#!/bin/bash
# Service validation script for VM testing

set -euo pipefail

echo "=== Service Validation Test ==="
echo ""

# Docker tests
echo "→ Testing Docker..."
if systemctl is-active docker &>/dev/null; then
    echo "  ✓ Docker service is active"
else
    echo "  ✗ Docker service is NOT active"
    exit 1
fi

if systemctl is-enabled docker &>/dev/null; then
    echo "  ✓ Docker service is enabled"
else
    echo "  ✗ Docker service is NOT enabled"
    exit 1
fi

if docker --version &>/dev/null; then
    echo "  ✓ Docker command works: $(docker --version)"
else
    echo "  ✗ Docker command failed"
    exit 1
fi

if timeout 10 docker ps &>/dev/null; then
    echo "  ✓ Docker daemon is responding"
else
    echo "  ✗ Docker daemon not responding (may need group membership)"
fi

echo ""

# MongoDB tests
echo "→ Testing MongoDB..."
if [ -f /etc/fedora-release ]; then
    SERVICE="mongod"
else
    SERVICE="mongodb"
fi

if systemctl is-active "$SERVICE" &>/dev/null; then
    echo "  ✓ MongoDB service is active"
else
    echo "  ✗ MongoDB service is NOT active"
    exit 1
fi

if systemctl is-enabled "$SERVICE" &>/dev/null; then
    echo "  ✓ MongoDB service is enabled"
else
    echo "  ✗ MongoDB service is NOT enabled"
    exit 1
fi

if mongod --version &>/dev/null; then
    echo "  ✓ mongod command works: $(mongod --version | head -1)"
else
    echo "  ✗ mongod command failed"
    exit 1
fi

if timeout 10 mongosh --eval "db.version()" &>/dev/null; then
    echo "  ✓ MongoDB is responding: $(mongosh --quiet --eval 'db.version()')"
else
    echo "  ✗ MongoDB not responding"
    exit 1
fi

echo ""
echo "✓ All service tests passed!"
```

Usage:
```bash
chmod +x test-services.sh
./test-services.sh
```

## Results Documentation

### Create Test Report

Save results in `.plans/validation/vm-results/YYYY-MM-DD-test-name.md`:

```markdown
# VM Test Results - YYYY-MM-DD

## Test Environment

- **VM**: Fedora 41 / Arch Linux
- **Profile**: work / personal
- **Branch**: refactor/collision-free-installers
- **Commit**: <commit-hash>
- **Date**: YYYY-MM-DD

## Service Test Results

### Docker

- Status: ✓ Active / ✗ Failed
- Enabled: ✓ Yes / ✗ No
- Version: X.Y.Z
- Docker ps: ✓ Works / ✗ Failed
- Test container: ✓ Success / ✗ Failed
- After reboot: ✓ Active / ✗ Failed

### MongoDB

- Status: ✓ Active / ✗ Failed
- Enabled: ✓ Yes / ✗ No
- Version: X.Y.Z
- Connection: ✓ Success / ✗ Failed
- Replica set: ✓ Initialized / ✗ Failed
- After reboot: ✓ Active / ✗ Failed

## Installation Flow

- System packages: ✓ Success / ✗ Failed
- User packages: ✓ Success / ✗ Failed
- Profile packages: ✓ Success / ✗ Failed
- Total time: X minutes
- Categories succeeded: N
- Categories failed: N

## Issues Found

- Issue 1: Description and resolution
- Issue 2: Description and resolution

## Artifacts

- Logs: `vm-results/YYYY-MM-DD/logs/`
- Screenshots: `vm-results/YYYY-MM-DD/screenshots/`
- State DB: `vm-results/YYYY-MM-DD/state.db.json`

## Conclusion

✓ Ready to merge / ⚠ Issues found / ✗ Blocking issues
```

## CI/CD Integration (Future)

If VM testing becomes critical, consider:

### GitHub Actions Self-Hosted Runner

```yaml
# .github/workflows/vm-test.yml
name: VM Testing

on:
  workflow_dispatch:  # Manual only
  schedule:
    - cron: '0 0 1 * *'  # Monthly

jobs:
  vm-test:
    runs-on: self-hosted  # Requires VM host
    steps:
      - name: Create test VM
        run: ./tests/vm-scripts/create-vm.sh

      - name: Run service tests
        run: ./tests/vm-scripts/test-services.sh

      - name: Collect results
        run: ./tests/vm-scripts/collect-results.sh

      - name: Cleanup
        run: ./tests/vm-scripts/cleanup-vm.sh
```

### Cloud-Based VM Testing

Use Terraform + cloud provider:
- DigitalOcean droplets (~$0.10/test)
- AWS EC2 spot instances (~$0.05/test)
- Linode instances (~$0.08/test)

## Troubleshooting

### Service Won't Start

```bash
# Check service logs
sudo journalctl -u docker -n 50
sudo journalctl -u mongod -n 50

# Check for port conflicts
sudo ss -tlnp | grep 2376  # Docker
sudo ss -tlnp | grep 27017 # MongoDB

# Check service dependencies
systemctl list-dependencies docker
systemctl list-dependencies mongod

# Try manual start
sudo systemctl start docker
sudo systemctl start mongod
```

### Service Not Enabled

```bash
# Check why it wasn't enabled
grep "enable_services" ~/.cache/dotfiles-install/*.log

# Enable manually
sudo systemctl enable --now docker
sudo systemctl enable --now mongod
```

### Docker Permission Denied

```bash
# Check group membership
groups | grep docker

# If missing, add user
sudo usermod -aG docker $USER

# Logout and back in required
# Or use newgrp temporarily:
newgrp docker
```

## Automation Scripts

See `tests/vm-scripts/` directory for:
- `create-vm.sh` - Automated VM creation
- `test-services.sh` - Service validation
- `collect-results.sh` - Result collection
- `cleanup-vm.sh` - VM teardown

## Cost Estimate

### Local VMs (libvirt)
- **Cost**: Free
- **Time**: 30-60 minutes setup + 15 minutes per test
- **Maintenance**: Medium (disk space, updates)

### Cloud VMs
- **Cost**: $0.05-0.10 per test run
- **Time**: 5 minutes setup + 15 minutes per test
- **Maintenance**: Low (ephemeral)

### Recommendation

- **Development**: Use local VMs or Docker tests
- **Pre-release**: Run VM tests manually
- **Production**: Consider cloud-based automated tests if budget allows
