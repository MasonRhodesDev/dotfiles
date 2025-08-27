# Software Installers Documentation

Automated software installation system supporting both Fedora and Arch Linux for a complete Hyprland desktop environment.

## Overview

The installer system provides:
- **Ordered execution** - Dependencies installed in correct sequence
- **Multi-platform support** - Fedora (dnf) and Arch (pacman/AUR)
- **Idempotent operations** - Safe to run multiple times
- **Error handling** - Graceful failure and recovery

## Installation Scripts

### Execution Order

Scripts run in numbered order to handle dependencies:

1. **`executable_00_utils.sh`** - Core utilities and foundations
2. **`executable_01_terminal.sh`** - Terminal emulators and shell tools  
3. **`executable_02_node.sh`** - Node.js and JavaScript development
4. **`executable_03_hyprland.sh`** - Hyprland compositor ecosystem
5. **`executable_04_git_based.sh`** - Git repository software
6. **`executable_06_browser.sh`** - Web browsers and extensions

### Platform Detection

Each script automatically detects the system:

```bash
#!/bin/sh
set -eu

# Detect package manager
if command -v dnf > /dev/null 2>&1; then
    PACKAGE_MANAGER="dnf"
elif command -v pacman > /dev/null 2>&1; then
    PACKAGE_MANAGER="pacman"
else
    echo "Unsupported system: requires Fedora or Arch Linux"
    exit 1
fi
```

## Individual Scripts

### 00_utils.sh - Core Utilities

**Purpose:** Essential system utilities and development tools

**Fedora packages:**
```bash
sudo dnf install -y \
    git curl wget unzip \
    gcc make cmake \
    python3 python3-pip \
    neovim vim \
    htop btop \
    ripgrep fd-find bat
```

**Arch packages:**
```bash
# Install yay AUR helper first (done automatically)
sudo pacman -S --noconfirm \
    vim curl git jq \
    thunar \
    wireplumber \
    networkmanager \
    go \
    keychain
    
# AUR packages
yay -S --noconfirm \
    solaar \
    ttf-fira-code \
    piper \
    headsetcontrol
```

### 01_terminal.sh - Terminal Tools

**Purpose:** Terminal emulators, multiplexers, and shell enhancement

**Fedora:**
```bash
# Terminal applications
sudo dnf install -y foot tmux

# Oh My Posh (cross-platform)
curl -s https://ohmyposh.dev/install.sh | bash -s
```

**Arch:**
```bash
# Terminal applications  
sudo pacman -S --noconfirm foot tmux

# Oh My Posh from AUR
yay -S --noconfirm oh-my-posh-bin
```

### 02_node.sh - Node.js Development

**Purpose:** Node.js runtime managed by fnm and alternative runtimes

**Fedora:**
```bash
# Install fnm via cargo
sudo dnf install -y cargo
cargo install fnm

# Install Node.js LTS via fnm
eval "$(fnm env --use-on-cd)"
fnm install --lts
fnm use lts-latest
fnm default lts-latest

# Bun runtime
curl -fsSL https://bun.sh/install | bash
```

**Arch:**
```bash
# Install fnm from AUR
yay -S --noconfirm fnm-bin

# Install Node.js LTS via fnm
eval "$(fnm env --use-on-cd)"
fnm install --lts
fnm use lts-latest
fnm default lts-latest

# Bun from AUR
yay -S --noconfirm bun-bin
```

### 03_hyprland.sh - Hyprland Ecosystem

**Purpose:** Wayland compositor and desktop environment

**Fedora (COPR repositories):**
```bash
# Enable COPR repositories
sudo dnf copr enable -y solopasha/hyprland
sudo dnf copr enable -y heus-sueh/packages

# Set repository priorities
echo -e '[solopasha-hyprland]\npriority=1' | sudo tee /etc/yum.repos.d/solopasha-hyprland.repo
echo -e '[heus-sueh-packages]\npriority=2' | sudo tee /etc/yum.repos.d/heus-sueh-packages.repo

# Install Hyprland ecosystem
sudo dnf install -y \
    hyprland \
    hyprlock hypridle hyprpicker \
    waybar wofi \
    swaync swayosd \
    xdg-desktop-portal-hyprland \
    wl-clipboard grim slurp \
    matugen
```

**Arch (official/AUR):**
```bash
# Install from official repos
sudo pacman -S --noconfirm \
    hyprland \
    waybar wofi \
    dunst pavucontrol \
    xdg-desktop-portal-hyprland \
    wl-clipboard grim slurp

# AUR packages (prefer -git versions)
yay -S --noconfirm \
    hyprlock-git \
    hypridle-git \
    hyprpicker-git \
    swaybg-git \
    matugen \
    swaync-git \
    swayosd-git
```

### 04_git_based.sh - Repository Software

**Purpose:** Software installed from Git repositories

**Cross-platform approach:**
```bash
#!/bin/sh
set -eu

# Helper function for conditional execution
run_if_exists() {
    script_path="$1"
    if [ -x "$script_path" ]; then
        echo "Running $(basename "$script_path")"
        "$script_path"
    else
        echo "Skipping $(basename "$script_path") - not found or not executable"
    fi
}

# Run git-based installers in order
run_if_exists "./git_installers/astal/install.sh"
run_if_exists "./git_installers/hyprpanel/install.sh"

exit 0
```

### 06_browser.sh - Web Browsers

**Purpose:** Web browsers and development tools

**Fedora:**
```bash
# Firefox (pre-installed on Fedora)
# Chromium from RPM Fusion
sudo dnf install -y chromium

# Development browsers
flatpak install -y flathub com.google.Chrome
```

**Arch:**
```bash
# Browsers from official repos
sudo pacman -S --noconfirm firefox chromium

# Development browsers from AUR
yay -S --noconfirm vivaldi
```

## Platform-Specific Features

### Fedora Linux

**COPR Repository Management:**
- Hyprland ecosystem from solopasha/hyprland
- Additional tools from heus-sueh/packages
- Repository priorities for package resolution

**RPM Fusion Integration:**
```bash
# Enable free and non-free repositories
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### Arch Linux

**AUR Helper Setup:**
```bash
# Install yay if not present
if ! command -v yay > /dev/null 2>&1; then
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
fi
```

**Multilib Repository:**
```bash
# Enable multilib in /etc/pacman.conf
sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
sudo pacman -Sy
```

## Running Installers

### Complete Installation

```bash
# Run all installers in order
for script in ~/.local/share/chezmoi/software_installers/executable_*.sh; do
    [ -x "$script" ] && echo "Running $(basename "$script")" && "$script"
done
```

### Individual Installation

```bash
# Run specific installer
./software_installers/executable_03_hyprland.sh

# Check what would be installed
bash -x ./software_installers/executable_03_hyprland.sh
```

### Post-Installation

```bash
# Enable systemd user services
systemctl --user enable waybar-reload.path
systemctl --user start waybar-reload.path

# Configure Git (if not done)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Adding New Installers

### Creating a New Script

1. **Follow naming convention:**
```bash
executable_07_development.sh  # Next number in sequence
```

2. **Use template structure:**
```bash
#!/bin/sh
set -eu

# Platform detection
if command -v dnf > /dev/null 2>&1; then
    # Fedora-specific installation
    echo "Installing development tools on Fedora"
    sudo dnf install -y package1 package2
elif command -v pacman > /dev/null 2>&1; then
    # Arch-specific installation  
    echo "Installing development tools on Arch"
    sudo pacman -S --noconfirm package1 package2
else
    echo "Unsupported platform"
    exit 1
fi

# Cross-platform post-installation
echo "Configuring development environment"
# Additional setup commands

exit 0
```

3. **Make executable:**
```bash
chmod +x software_installers/executable_07_development.sh
```

### Platform-Specific Considerations

**Fedora:**
- Check if COPR repositories are needed
- Consider RPM Fusion packages
- Use `dnf install -y` for non-interactive installation

**Arch:**
- Separate official packages from AUR packages
- Use `yay -S --noconfirm` for AUR packages  
- Check if multilib repository is needed

## Git-Based Installers

For complex software built from source:

### Directory Structure
```
git_installers/
├── astal/
│   └── install.sh
└── hyprpanel/
    └── install.sh
```

### Example Git Installer
```bash
#!/bin/bash
set -eu

INSTALL_DIR="$HOME/.local/share/astal"
REPO_URL="https://github.com/astal-sh/astal"

# Platform-specific dependencies
if command -v dnf > /dev/null 2>&1; then
    sudo dnf install -y meson ninja-build gobject-introspection-devel
elif command -v pacman > /dev/null 2>&1; then
    sudo pacman -S --noconfirm meson ninja gobject-introspection
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR"
    git pull
else
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Build and install
meson setup build
ninja -C build
sudo ninja -C build install

echo "Astal installed successfully"
```

## Error Handling

### Common Issues

**Repository Access Denied:**
```bash
# Fedora COPR access
sudo dnf copr enable -y repo/name
# If fails, check internet connection and repository name

# Arch AUR access  
yay -S package-name
# If fails, check if yay is installed and configured
```

**Package Conflicts:**
```bash
# Fedora
sudo dnf check
sudo dnf distro-sync

# Arch
sudo pacman -Syu
sudo pacman -S --needed base-devel
```

**Missing Dependencies:**
```bash
# Check logs in ~/.software_installer_logs/
ls -la ~/.software_installer_logs/

# Re-run specific installer
./software_installers/executable_XX_name.sh
```

### Logging

Installers log their output:

```bash
# Log location
~/.software_installer_logs/

# View recent logs
tail -f ~/.software_installer_logs/executable_03_hyprland.sh.log
```

## Testing

### Virtual Machine Testing

Test installers in clean environments:

**Fedora:**
```bash
# Download Fedora Workstation ISO
# Install in VM with minimal packages
# Run installer suite
```

**Arch:**
```bash  
# Use archiso or EndeavourOS
# Install base system
# Run installer suite
```

### Dependency Verification

```bash
# Check installed packages
dnf list installed | grep hyprland  # Fedora
pacman -Q | grep hyprland           # Arch

# Verify binaries
command -v hyprland waybar wofi
```

## Maintenance

### Updating Installers

1. **Test on both platforms** before committing changes
2. **Update version pins** for git-based software
3. **Check repository availability** (COPR/AUR status)
4. **Validate package names** haven't changed

### Repository Monitoring

**Fedora COPR:**
- Check https://copr.fedorainfracloud.org/
- Monitor solopasha/hyprland updates
- Watch for Fedora version compatibility

**Arch AUR:**
- Monitor AUR package updates
- Check for maintainer changes
- Validate build dependencies

---

This installer system ensures consistent, reliable deployment across both Fedora and Arch Linux systems while maintaining platform-specific optimizations.