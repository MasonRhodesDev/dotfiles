#!/bin/bash
set -euo pipefail

# Marble Shell installer for Arch & Fedora
# - Arch: follows official AUR-based instructions
# - Fedora: best-effort dependency mapping + Astal from source via sibling installer

REPO_URL="https://github.com/marble-shell/shell.git"
INSTALL_ROOT="$HOME/git_installers/marble-shell"
REPO_DIR="$INSTALL_ROOT/shell"

ensure_dir() {
  mkdir -p "$INSTALL_ROOT"
}

is_arch() { command -v pacman &>/dev/null; }
is_fedora() { command -v dnf &>/dev/null; }

ensure_pnpm_and_esbuild() {
  if ! command -v node &>/dev/null; then
    if is_fedora; then
      sudo dnf install -y nodejs npm || true
    fi
  fi

  if ! command -v pnpm &>/dev/null; then
    if command -v corepack &>/dev/null; then
      corepack enable || true
      corepack prepare pnpm@latest --activate || true
    fi
  fi

  if ! command -v pnpm &>/dev/null; then
    if command -v npm &>/dev/null; then
      sudo npm i -g pnpm || true
    fi
  fi

  if ! command -v esbuild &>/dev/null; then
    if is_fedora; then
      sudo dnf install -y esbuild || true
    fi
  fi

  if ! command -v esbuild &>/dev/null; then
    if command -v npm &>/dev/null; then
      sudo npm i -g esbuild || true
    fi
  fi
}

install_deps_arch() {
  # Official docs for Arch
  # yay -S gjs gtk4 gtk4-layer-shell libadwaita pnpm esbuild libastal-meta
  if ! command -v yay &>/dev/null; then
    echo "Installing yay AUR helper..."
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
  fi
  yay -S --needed --noconfirm gjs gtk4 gtk4-layer-shell libadwaita pnpm esbuild libastal-meta
}

install_deps_fedora() {
  # Best-effort mapping for Fedora
  sudo dnf install -y \
    git gjs gtk4 libadwaita \
    gtk4-devel gtk4-layer-shell-devel libadwaita-devel \
    meson ninja-build gobject-introspection-devel

  # pnpm/esbuild handled separately to allow npm fallback
  ensure_pnpm_and_esbuild

  # Ensure Astal libraries (prefer local installer if available)
  if [ -x "$HOME/git_installers/astal/executable_install.sh" ]; then
    "$HOME/git_installers/astal/executable_install.sh"
  else
    echo "Astal installer not found locally; attempting to install packaged astal libraries (if available)."
    sudo dnf install -y --skip-unavailable astal astal-gjs astal-gtk4 astal-io astal-libs || true
  fi
}

clone_or_update_repo() {
  ensure_dir
  if [ -d "$REPO_DIR/.git" ]; then
    echo "Updating existing Marble Shell repository..."
    (cd "$REPO_DIR" && git pull --ff-only || true)
  else
    echo "Cloning Marble Shell repository..."
    if ! git clone "$REPO_URL" "$REPO_DIR"; then
      cat <<EOF
ERROR: Unable to clone $REPO_URL
This project is closed-source and requires GitHub Sponsors access.
See: https://github.com/sponsors/Aylur and the installation guide.
EOF
      exit 1
    fi
  fi
}

build_and_install() {
  cd "$REPO_DIR"

  if command -v pnpm &>/dev/null; then
    pnpm install
  else
    echo "pnpm is required but not found. Aborting."
    exit 1
  fi

  # Clean previous build if present
  [ -d build ] && rm -rf build
  meson setup build
  sudo meson install -C build
}

main() {
  if is_arch; then
    install_deps_arch
  elif is_fedora; then
    install_deps_fedora
  else
    echo "Unsupported distribution. Only Arch and Fedora are handled here."
    exit 0
  fi

  clone_or_update_repo
  build_and_install

  echo "Marble Shell installation completed. Try: marble --help"
}

main "$@"
