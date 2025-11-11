# Software Installation System

Registry-based package installation with collision detection, state tracking, and profile support for Fedora 41 and Arch Linux.

## Architecture

### Package Registry (`packages.toml`)

Centralized TOML file defining all software organized into three sections:

- **common**: All machines (personal and work)
- **work**: Work machines only
- **personal**: Personal machines only

Each category supports:
- Multi-platform (Fedora, Arch)
- Multiple sources (dnf, pacman, yay, cargo, flatpak)
- Repository management (COPR, custom repos)
- Service configuration
- User groups
- Post-install hooks
- Optional packages

### Profile Detection

Profiles determined by hostname:
- `mason-work` → work profile
- Everything else → personal profile

Configuration in `.chezmoi.toml.tmpl`:
```toml
[data.profile]
    type = "work" | "personal"
    optional_packages = ["python_dev", "java_dev"]
```

### Execution Flow

```
chezmoi apply
  ↓
Dotfiles applied to ~ (always succeeds)
  ↓
run_after_10-system-packages.sh.tmpl (sudo required)
  ├─ build_tools
  ├─ core_utils
  ├─ hyprland
  └─ ...
  ↓
run_after_20-user-packages.sh.tmpl (no sudo)
  ├─ shell_tools
  ├─ node_tooling
  └─ ...
  ↓
run_after_30-profile-{work|personal}.sh.tmpl (conditional)
  ├─ docker (work)
  ├─ gaming (personal)
  └─ ...
  ↓
run_after_90-post-install.sh.tmpl (hooks)
  ↓
run_after_99-report.sh.tmpl (summary)
```

## Library System

Located in `dot_local/share/chezmoi-libs/`:

### lib-helpers.sh.tmpl (~795 lines)

**Main Functions:**
- `install_packages_from_registry()` - Main orchestrator
- `retry_with_backoff()` - Network retry with exponential backoff
- `validate_prerequisites()` - Check yq, network, disk, sudo
- `parse_packages()` - Extract from TOML registry
- `install_packages()` - Native package manager
- `install_aur_packages()` - AUR via yay (Arch)
- `install_flatpak_packages()` - Flatpak apps
- `install_cargo_packages()` - Rust crates
- `enable_repos_from_registry()` - COPR/custom repos
- `enable_services()` - systemd services
- `add_user_to_groups()` - User groups

**Platform Detection:**
- `get_distro()` - Returns "fedora" or "arch"
- `get_package_manager()` - Returns package manager command
- `check_min_version()` - Validate OS version

### lib-state.sh.tmpl (~250 lines)

**State Management:**
- `init_state_db()` - Initialize JSON database
- `acquire_lock()` / `release_lock()` - PID-based locking
- `needs_reinstall()` - Checksum-based change detection
- `record_category_*()` - Track installation status
- `register_package()` - Add to package registry
- `get_package_source()` - Query installation source

**Database Location:** `~/.local/state/chezmoi-installs/state.db.json`

**Schema:**
```json
{
  "schema_version": "1.0",
  "metadata": {
    "os": "linux",
    "distro": "fedora",
    "version": "41",
    "profile": "work"
  },
  "phases": {
    "system": {
      "categories": {
        "hyprland": {
          "status": "success",
          "completed": "2025-11-10T10:30:00Z",
          "packages_installed": ["hyprland", "waybar"],
          "checksum": "abc123..."
        }
      }
    }
  },
  "package_registry": {
    "hyprland": {
      "source": "dnf",
      "installed": "2025-11-10T10:30:00Z"
    }
  }
}
```

### lib-collision.sh.tmpl (~250 lines)

**Collision Detection:**
- `check_package_collision()` - Multi-source check
- `is_package_installed()` - Check by specific source
- `check_known_conflict()` - Known conflicts (docker/podman)
- `check_file_collision()` - User binary conflicts
- `check_category_collisions()` - Run all checks

**Conflicts Database:** `~/.local/state/chezmoi-installs/collisions.db.json`

### lib-logging.sh.tmpl (~143 lines)

**Logging System:**
- `log_debug()`, `log_info()`, `log_warn()`, `log_error()`
- `log_phase_start()` / `log_phase_end()`
- `log_category_*()` - Category-level logging
- `init_log_file()` - Initialize with rotation
- `cleanup_old_logs()` - Keep last 10 logs

**Log Location:** `~/.local/state/chezmoi-installs/install.log`

## Platform Support

### Fedora (Primary)

**Version:** 40+ (tested on 41)

**Package Manager:** dnf

**COPR Support:**
```toml
repos = ["copr:solopasha/hyprland"]
```

**Custom Repos:**
```toml
repos = ["https://example.com/repo"]
repo_keys = ["https://example.com/key.gpg"]
```

### Arch Linux (Full Parity)

**Package Manager:** pacman

**AUR Helper:** yay (auto-installed)

**Multilib:** Enabled automatically for gaming packages

**Package Preference:**
```toml
[common.hyprland.arch]
packages = ["hyprland"]      # Official repos
aur_packages = ["hyprlock-git"]  # AUR only
```

## Package Registry Format

### Basic Category

```toml
[common.my_tool]
description = "My awesome tool"
install_level = "user"  # or "system"
optional = false

  [common.my_tool.fedora]
  packages = ["my-tool"]

  [common.my_tool.arch]
  packages = ["my-tool"]
```

### Advanced Category

```toml
[work.docker]
description = "Docker container runtime"
install_level = "system"
depends_on = ["build_tools"]
conflicts = ["podman"]

  [work.docker.fedora]
  packages = ["docker-ce", "docker-compose"]
  repos = ["https://download.docker.com/linux/fedora/docker-ce.repo"]
  repo_keys = ["https://download.docker.com/linux/fedora/gpg"]
  services = ["docker"]
  user_groups = ["docker"]
  post_install = []
  min_version = "40"

  [work.docker.arch]
  packages = ["docker", "docker-compose"]
  services = ["docker"]
  user_groups = ["docker"]
```

### Optional Packages

```toml
[common.python_dev]
description = "Python development tools"
install_level = "user"
optional = true

  [common.python_dev.fedora]
  packages = ["python3-dev", "pipx"]
```

Enable in `.chezmoi.toml.tmpl`:
```toml
[data.profile]
    optional_packages = ["python_dev"]
```

## Adding New Packages

1. **Add to registry:**
```bash
vim software_installers/packages.toml
```

2. **Define for both platforms:**
```toml
[common.newtool]
description = "New tool"
install_level = "user"

  [common.newtool.fedora]
  packages = ["newtool"]

  [common.newtool.arch]
  aur_packages = ["newtool-bin"]
```

3. **Apply changes:**
```bash
chezmoi apply  # Installers run automatically
```

## Manual Execution

### Run All Phases

```bash
cd ~/.local/share/chezmoi
./run_after_10-system-packages.sh  # System
./run_after_20-user-packages.sh    # User
./run_after_30-profile-work.sh     # Profile (if work)
```

### Run Specific Category

Edit installer script to only install specific category:
```bash
install_packages_from_registry "hyprland"
```

### Test Registry Parsing

```bash
source ~/.local/share/chezmoi-libs/lib-helpers.sh
parse_packages "common.hyprland" "fedora" "packages"
```

## State Management

### View State

```bash
# Full state
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.'

# Phases
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases'

# Installed packages
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.package_registry'

# Failed categories
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases.system.categories | to_entries[] | select(.value.status == "failed")'
```

### Reset State

```bash
# Remove state (will re-install everything)
rm ~/.local/state/chezmoi-installs/state.db.json

# Remove lock if stuck
rm ~/.local/state/chezmoi-installs/install.lock

# Re-run installers
chezmoi apply
```

## Troubleshooting

### Package Not Installing

```bash
# 1. Check profile
cat ~/.config/chezmoi/chezmoi.toml | grep type

# 2. Check if optional
cat software_installers/packages.toml | grep -A5 "package_name"

# 3. Check OS version
cat /etc/os-release

# 4. Check state
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases.system.categories.package_name'
```

### Repository Issues

**Fedora COPR:**
```bash
# List enabled repos
dnf repolist

# Check specific repo
ls /etc/yum.repos.d/ | grep copr

# Re-enable
sudo dnf copr enable solopasha/hyprland
```

**Arch AUR:**
```bash
# Check yay
command -v yay

# Install yay manually
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si
```

### Collision Detected

```bash
# View collision database
cat ~/.local/state/chezmoi-installs/collisions.db.json

# Check package sources
rpm -q package-name        # Fedora
pacman -Q package-name     # Arch
cargo install --list | grep package
flatpak list | grep package
```

### Installation Stuck

```bash
# Check lock
cat ~/.local/state/chezmoi-installs/install.lock

# Remove stale lock (check PID first)
rm ~/.local/state/chezmoi-installs/install.lock

# View logs
tail -f ~/.local/state/chezmoi-installs/install.log
```

## Migration Notes

Old system (`executable_*.sh` in `software_installers/`) has been replaced:

**Old files (backed up as *.old):**
- `executable_00_utils.sh.old`
- `executable_01_terminal.sh.old`
- `executable_02_node.sh.old`
- `executable_03_hyprland.sh.old`
- `executable_04_git_based.sh.old`

**New system:**
- `packages.toml` - Central registry
- `run_after_*.sh.tmpl` - Chezmoi-native installers
- `dot_local/share/chezmoi-libs/` - Shared libraries

All functionality preserved with added features (collision detection, state tracking, profiles).
