#!/bin/bash

<<<<<<< Updated upstream
source "$(dirname "$0")/__helpers.sh"
=======
# Utils
echo "Installing Utils"
sudo dnf install -y vim snap curl git jq Thunar solaar wireplumber NetworkManager go gcc-go keychain powerline-fonts fira-code-fonts piper headsetcontrol
sudo mkdir -p /usr/local/share/fonts/

curl -OL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz
sudo mkdir -p /usr/local/share/fonts/FiraCode/
sudo tar -xvf FiraCode.tar.xz -C /usr/local/share/fonts/FiraCode
rm FiraCode.tar.xz

sudo fc-cache -f -v
>>>>>>> Stashed changes

echo "Installing core utilities..."

# Core development and system utilities
install_packages \
    "vim curl git jq gcc go keychain powerline-fonts fira-code-fonts piper headsetcontrol solaar wireplumber NetworkManager" \
    "vim curl git jq gcc go keychain powerline-fonts ttf-fira-code piper headsetcontrol solaar wireplumber networkmanager"

# Gaming/peripheral tools (Fedora specific)
if [ "$(get_distro)" = "fedora" ]; then
    # Add udev rules for SteelSeries headset
    echo 'SUBSYSTEM=="usb", ATTRS{idVendor}=="1038", ATTRS{idProduct}=="12ad", TAG+="uaccess"' | sudo tee /etc/udev/rules.d/99-steelseries-arctis-7x.rules
    sudo udevadm control --reload-rules
fi

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for current session
    if [ "$(get_distro)" = "arch" ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Install oh-my-posh via Homebrew
if ! command -v oh-my-posh &> /dev/null; then
    echo "Installing oh-my-posh..."
    brew install oh-my-posh
fi

<<<<<<< Updated upstream
echo "Core utilities installation complete!"
=======
exit 0
>>>>>>> Stashed changes
