# Software Installer System

Registry-based package installation with collision detection, state tracking, and profile support for Fedora 41 and Arch Linux.

## Architecture Overview

**Key Features:**
- Collision-free installation (prevents dnf/pacman/cargo/flatpak/AUR conflicts)
- State tracking with JSON database (idempotent, resumable)
- Profile-based separation (work vs personal)
- Error isolation (failures don't block dotfile application)
- Multi-phase execution (system → user → profile)

**Execution via chezmoi:**
```
chezmoi apply
  ↓ Dotfiles applied first (always succeeds)
  ↓
run_after_10-system-packages.sh.tmpl (system-level, sudo)
  ↓
run_after_20-user-packages.sh.tmpl (user-level, no sudo)
  ↓
run_after_30-profile-{work|personal}.sh.tmpl (conditional)
  ↓
run_after_90-post-install.sh.tmpl (hooks)
  ↓
run_after_99-report.sh.tmpl (summary)
```

## Package Registry (`packages.toml`)

Centralized TOML defining all packages in three sections:

**Sections:**
- `[common.*]` - All machines
- `[work.*]` - Work machines only
- `[personal.*]` - Personal machines only

**Example:**
```toml
[common.hyprland]
description = "Hyprland compositor"
install_level = "system"  # or "user"
optional = false

  [common.hyprland.fedora]
  packages = ["hyprland", "waybar"]
  repos = ["copr:solopasha/hyprland"]
  services = ["greetd"]

  [common.hyprland.arch]
  packages = ["hyprland", "waybar"]
  aur_packages = ["hyprlock-git"]
```

**Supported Fields:**
- `packages` - Native package manager (dnf/pacman)
- `aur_packages` - AUR packages (Arch only)
- `cargo_packages` - Rust crates
- `flatpak` - Flatpak apps
- `repos` - COPR repos or URLs
- `repo_keys` - GPG keys for custom repos
- `services` - systemd services to enable
- `user_groups` - Groups to add user to
- `post_install` - Hooks after installation
- `min_version` - Minimum OS version
- `depends_on` - Category dependencies
- `conflicts` - Conflicting packages

## Library System

Located in `~/.local/share/chezmoi-libs/`:

### lib-helpers.sh.tmpl (~795 lines)

**Main Functions:**
- `install_packages_from_registry(category)` - Main orchestrator
- `validate_prerequisites()` - Check yq, network, disk, sudo
- `retry_with_backoff(cmd)` - Network retry with exponential backoff
- `parse_packages(category, distro, field)` - Extract from TOML
- `install_packages(packages)` - Native package manager
- `install_aur_packages(packages)` - AUR via yay
- `install_flatpak_packages(packages)` - Flatpak
- `install_cargo_packages(packages)` - Cargo
- `enable_repos_from_registry(category)` - Enable COPR/repos
- `enable_services(services)` - Enable systemd services
- `add_user_to_groups(groups)` - Add user to groups
- `get_distro()` - Returns "fedora" or "arch"
- `should_install_category(category)` - Profile-aware check

### lib-state.sh.tmpl (~250 lines)

**State Tracking:**
- JSON database at `~/.local/state/chezmoi-installs/state.db.json`
- PID-based locking (`install.lock`)
- Checksum-based change detection
- Phase and category status tracking
- Package registry with source metadata

**Functions:**
- `init_state_db()` - Initialize database
- `acquire_lock()` / `release_lock()` - Mutual exclusion
- `needs_reinstall(category)` - Check if reinstall needed
- `record_category_*()` - Track status
- `register_package(name, source)` - Add to registry
- `get_package_source(name)` - Query installation source

### lib-collision.sh.tmpl (~250 lines)

**Collision Detection:**
- Multi-source package detection (dnf, pacman, cargo, flatpak, AUR)
- Known conflict checking (docker/podman)
- File collision warnings (~/bin, ~/.local/bin)

**Functions:**
- `check_package_collision(package)` - Detect conflicts
- `is_package_installed(package, source)` - Check specific source
- `check_known_conflict(package)` - Known conflicts database
- `check_category_collisions(category)` - Run all checks

**Conflicts Database:** `~/.local/state/chezmoi-installs/collisions.db.json`

### lib-logging.sh.tmpl (~143 lines)

**Structured Logging:**
- Color-coded levels (DEBUG, INFO, WARN, ERROR)
- Phase and category tracking
- Log file with rotation (keeps last 10)

**Functions:**
- `log_debug()`, `log_info()`, `log_warn()`, `log_error()`
- `log_phase_start()` / `log_phase_end()`
- `log_category_*()` - Category-level logging

**Log Location:** `~/.local/state/chezmoi-installs/install.log`

## Profile Detection

**Auto-detected by hostname:**
- `mason-work` → work profile
- All others → personal profile

**Configure in `.chezmoi.toml.tmpl`:**
```toml
[data.profile]
    type = "work"
    optional_packages = ["python_dev", "java_dev"]
```

**Profile-aware installation:**
- Work profile: Installs `[common.*]` + `[work.*]`
- Personal profile: Installs `[common.*]` + `[personal.*]`

## State Database Schema

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
          "status": "success|failed|in_progress",
          "completed": "2025-11-10T10:30:00Z",
          "packages_installed": ["hyprland", "waybar"],
          "checksum": "sha256..."
        }
      }
    },
    "user": { ... },
    "profile": { ... }
  },
  "package_registry": {
    "hyprland": {
      "source": "dnf",
      "installed": "2025-11-10T10:30:00Z"
    }
  },
  "migration_applied": true
}
```

## Platform Support

### Fedora (Primary)
- Version: 40+ (tested on 41)
- Package manager: dnf
- COPR repositories supported
- Custom repos with GPG keys

### Arch Linux (Full Parity)
- Package manager: pacman
- AUR helper: yay (auto-installed)
- Multilib repo (auto-enabled for gaming)
- Official repos preferred over AUR

## Adding New Packages

1. **Edit `packages.toml`:**
```toml
[common.newtool]
description = "New tool"
install_level = "user"

  [common.newtool.fedora]
  packages = ["newtool"]

  [common.newtool.arch]
  aur_packages = ["newtool-bin"]
```

2. **Run `chezmoi apply`** - Installation happens automatically

## Manual Execution

**Run all phases:**
```bash
cd ~/.local/share/chezmoi
./run_after_10-system-packages.sh
./run_after_20-user-packages.sh
./run_after_30-profile-work.sh  # if work profile
```

**View state:**
```bash
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases'
```

**Reset state:**
```bash
rm ~/.local/state/chezmoi-installs/state.db.json
chezmoi apply
```

## System Tracking

**Manifest:** `.system_manifest.json` (root of repo)

Tracks all systems using this dotfiles repo:
```json
{
  "systems": {
    "mason-work": {
      "os": "linux",
      "distro": "fedora",
      "version": "41",
      "profile": "work",
      "optional_packages": ["python_dev"],
      "last_seen": "2025-11-10T15:45:00Z"
    }
  }
}
```

Updated by `run_once_after_99-track-system.sh`.

## Troubleshooting

**Check state:**
```bash
cat ~/.local/state/chezmoi-installs/state.db.json | jq '.phases.system.categories'
```

**View logs:**
```bash
tail -f ~/.local/state/chezmoi-installs/install.log
```

**Remove lock:**
```bash
rm ~/.local/state/chezmoi-installs/install.lock
```

**Check collisions:**
```bash
cat ~/.local/state/chezmoi-installs/collisions.db.json
```

**Package source:**
```bash
rpm -q package-name        # Fedora
pacman -Q package-name     # Arch
cargo install --list | grep package
flatpak list | grep package
```

## Testing

Docker-based tests for both platforms:
```bash
./tests/run-tests.sh         # All
./tests/run-tests.sh fedora  # Fedora only
./tests/run-tests.sh arch    # Arch only
```

See [tests/README.md](../tests/README.md) for details.
