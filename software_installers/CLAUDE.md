# Software Installer System

Automated software installation and configuration using a centralized package registry with profile-based separation.

## Architecture

### Package Registry (`packages.toml`)

Centralized TOML file defining all software packages organized into three sections:

- **common**: Packages installed on all machines (personal and work)
- **work**: Packages only for work machines
- **personal**: Packages only for personal machines

Each package category supports:
- Multi-platform definitions (Fedora, Arch Linux)
- Package manager integration (dnf, pacman, yay, cargo, flatpak)
- Repository management (COPR, custom repos)
- Service configuration
- User group management
- Post-install scripts
- Optional packages (per-system enablement)

### Profile Detection

Profiles are automatically determined by hostname:
- `mason-work` → work profile
- Other hostnames → personal profile

Configuration in `.chezmoi.toml.tmpl`:
```toml
[data.profile]
    type = "work" | "personal"
    optional_packages = ["python_dev", "java_dev", ...]
```

### Execution Order

Scripts run in numbered order:

#### Common (All Machines)
1. `executable_00_common_core.sh` - Core system utilities
2. `executable_01_common_terminal.sh` - Terminal tools and Node.js
3. `executable_02_common_desktop.sh` - Hyprland ecosystem and browsers  
4. `executable_03_common_dev.sh` - IDEs and development tools

#### Work Machines Only
5. `executable_04_work_tools.sh` - Docker, MongoDB, AWS, VPN, Kubernetes
6. `executable_05_work_apps.sh` - Slack, Zoom, Postman

#### Personal Machines Only
7. `executable_06_personal_apps.sh` - Gaming, media creation, music
8. `executable_07_personal_social.sh` - Social apps, password manager

## Platform Support

### Fedora (Primary)
- Minimum version: 40
- Package manager: dnf
- COPR repository support
- Currently tested on: Fedora 41

### Arch Linux (Full Parity)
- Package manager: pacman
- AUR helper: yay (auto-installed)
- Hyprland ecosystem uses `-git` variants
- Multilib repo support for gaming

## Helper Functions (`__helpers.sh.tmpl`)

### Core Functions
- `get_distro()` - Detect Fedora or Arch
- `get_category_section()` - Determine common/work/personal
- `should_install_category()` - Profile-aware installation check
- `is_optional_enabled()` - Check optional package enablement

### Installation Functions
- `install_packages_from_registry()` - Main installer with full registry support
- `install_packages()` - Native package manager
- `install_aur_packages()` - AUR packages (Arch only)
- `install_flatpak_packages()` - Flatpak apps
- `install_cargo_packages()` - Rust crates
- `enable_repos_from_registry()` - Repository management
- `enable_services()` - Systemd service management
- `add_user_to_groups()` - User group configuration

### Registry Parsing
- `parse_packages()` - Extract package lists from TOML
- `check_min_version()` - Validate OS version requirements
- `list_section_categories()` - List all categories in section

## System Tracking

### Manifest File (`.system_manifest.json`)

Automatically generated on each `chezmoi apply`:

```json
{
  "systems": {
    "mason-work": {
      "os": "linux",
      "distro": "fedora",
      "version": "41",
      "arch": "amd64",
      "profile": "work",
      "optional_packages": ["python_dev", "java_dev"],
      "last_seen": "2025-10-22T15:45:00Z",
      "first_seen": "2025-08-01T10:00:00Z"
    }
  },
  "last_updated": "2025-10-22T15:45:00Z"
}
```

### Tracking Script

`run_once_after_99-track-system.sh` automatically:
- Records system details (OS, distro, version, arch)
- Tracks profile type (work/personal)
- Logs optional packages enabled
- Maintains first/last seen timestamps

## Adding New Packages

### 1. Add to `packages.toml`

```toml
[common.my_tool]
description = "My awesome tool"
  [common.my_tool.fedora]
  packages = ["my-tool"]
  
  [common.my_tool.arch]
  packages = ["my-tool"]
```

### 2. Optional: Make it Optional

```toml
[common.my_tool]
description = "My awesome tool"
optional = true
  # ... package definitions
```

Then enable in `.chezmoi.toml.tmpl`:
```toml
[data.profile]
    optional_packages = ["my_tool", ...]
```

### 3. Install in Script

Add to appropriate installer script:
```bash
install_packages_from_registry "my_tool"
```

## Manual Execution

### Run All Installers
```bash
cd ~/.local/share/chezmoi/software_installers
for script in executable_*.sh*; do
    [ -x "$script" ] && "$script"
done
```

### Run Specific Category
```bash
./executable_02_common_desktop.sh
```

### Test Without Installing
```bash
source __helpers.sh
get_category_section "docker"  # Returns: work
should_install_category "docker"  # Returns: 0 (yes) or 1 (no)
```

## Platform-Specific Notes

### Fedora
- COPR repos enabled automatically
- Repository priorities supported
- Custom repo keys handled
- DNF config-manager used for external repos

### Arch Linux
- yay AUR helper installed on first AUR package request
- Hyprland packages use `-git` suffix for bleeding-edge
- Multilib repo required for gaming packages
- Official repos prioritized over AUR when available

## Git-Based Installers

Located in `~/git_installers/`:

- **Astal**: Libraries for AGS v3 (Fedora & Arch)
- **HyprPanel**: Custom panel for Hyprland (Fedora & Arch)

Both support cross-platform installation with automatic dependency resolution.

## Migration from Old System

Old installer scripts backed up as `*.old`:
- `executable_00_utils.sh.old`
- `executable_01_terminal.sh.old`
- `executable_02_node.sh.old`
- `executable_03_hyprland.sh.old`
- `executable_04_git_based.sh.old`
- `05_ide.sh.tmpl.old`
- `executable_06_browser.sh.old`
- `08_mongo.sh.tmpl.old`
- `10_docker.sh.tmpl.old`

## Troubleshooting

### Package Not Installing
1. Check profile type: `echo $PROFILE_TYPE`
2. Verify category section: `get_category_section "package_name"`
3. Check if optional and enabled in `.chezmoi.toml.tmpl`
4. Verify OS version meets minimum requirements

### Repository Issues
- Fedora: Check `/etc/yum.repos.d/` for repo files
- Arch: Verify AUR helper (yay) is installed
- Check repo priorities in package registry

### yq Not Found
The helper will automatically install yq on first run.

## Future Enhancements

- [ ] Add macOS support (Homebrew)
- [ ] NixOS package definitions
- [ ] Automated testing framework
- [ ] Package version pinning
- [ ] Rollback mechanism
- [ ] Installation time tracking
- [ ] Dependency graph visualization
