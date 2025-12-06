{ pkgs ? import <nixpkgs> {} }:

let
  # Helper to fetch and extract Ubuntu 24.04 .deb packages
  fetchUbuntuDeb = { name, url, sha256 }: pkgs.runCommand name {
    nativeBuildInputs = [ pkgs.dpkg ];
    src = pkgs.fetchurl { inherit url sha256; };
  } ''
    dpkg-deb -x $src $out
    mkdir -p $out/lib
    # Copy libraries from usr/lib/x86_64-linux-gnu to lib/
    if [ -d "$out/usr/lib/x86_64-linux-gnu" ]; then
      cp -rL $out/usr/lib/x86_64-linux-gnu/* $out/lib/
    fi
    # Also check usr/lib
    if [ -d "$out/usr/lib" ]; then
      cp -rL $out/usr/lib/* $out/lib/ 2>/dev/null || true
    fi
  '';

  # Ubuntu 24.04 (Noble) libraries for Playwright WebKit
  ubuntuLibs = {
    icu74 = fetchUbuntuDeb {
      name = "libicu74";
      url = "http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu74_74.2-1ubuntu3_amd64.deb";
      sha256 = "0bpsmsndkyxcyqq096icgpkfa4g6skj8dhgs3irm8ciy3ai9g76j";
    };

    ffi8 = fetchUbuntuDeb {
      name = "libffi8";
      url = "http://mirrors.kernel.org/ubuntu/pool/main/libf/libffi/libffi8_3.4.6-1build1_amd64.deb";
      sha256 = "637e6a7744de08cd331a41f4efd0d24e6ea9064843dea9d1c6ca87bdb5f038a2";
    };

    jpeg8 = fetchUbuntuDeb {
      name = "libjpeg8";
      url = "http://mirrors.kernel.org/ubuntu/pool/main/libj/libjpeg8-empty/libjpeg8_8c-2ubuntu11_amd64.deb";
      sha256 = "1jdarvcv6l5l5ylpqfs247j9g96xl1l6v82qy4mgdp9bjy1dcvjd";
    };

    jpegTurbo8 = fetchUbuntuDeb {
      name = "libjpeg-turbo8";
      url = "http://mirrors.kernel.org/ubuntu/pool/main/libj/libjpeg-turbo/libjpeg-turbo8_2.1.5-2ubuntu2_amd64.deb";
      sha256 = "f68b5b23bc8a1688fb787d2aed7e2cdf895a73022f6a5025e183162dac4500b2";
    };
  };

  # Script to patch WebKit binaries
  patchWebkit = pkgs.writeShellScriptBin "patch-webkit" ''
    set -e

    WEBKIT_DIR="$HOME/.cache/ms-playwright/webkit-2203"

    if [ ! -d "$WEBKIT_DIR" ]; then
      echo "WebKit not found. Run: npx playwright install webkit"
      exit 1
    fi

    echo "Patching WebKit binaries to use Ubuntu 24.04 libraries..."

    for bin in "$WEBKIT_DIR"/minibrowser-*/bin/*; do
      if [ -f "$bin" ] && [ -x "$bin" ]; then
        echo "Patching: $bin"
        ${pkgs.patchelf}/bin/patchelf --set-rpath "${ubuntuLibPath}:${nixLibPath}" "$bin" 2>/dev/null || true
      fi
    done

    for lib in "$WEBKIT_DIR"/minibrowser-*/lib/*.so*; do
      if [ -f "$lib" ]; then
        echo "Patching: $lib"
        ${pkgs.patchelf}/bin/patchelf --set-rpath "${ubuntuLibPath}:${nixLibPath}" "$lib" 2>/dev/null || true
      fi
    done

    echo "✓ WebKit patched successfully"
  '';

  # Standard Playwright dependencies from nixpkgs
  playwrightDeps = with pkgs; [
    # Graphics and X11
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    xorg.libxshmfence
    mesa
    libGL
    libdrm

    # GTK and accessibility (WebKit critical)
    gtk3
    at-spi2-atk
    at-spi2-core
    libsecret
    libnotify
    libappindicator-gtk3

    # Core libraries
    alsa-lib
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    libxkbcommon
    nspr
    nss
    pango
    libpng
    zlib

    # Wayland support
    wayland

    # Media
    ffmpeg
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    vulkan-loader

    # Fonts
    liberation_ttf
    dejavu_fonts

    # Additional WebKit dependencies
    harfbuzz
    libwebp
    libxml2
    sqlite

    # System libraries
    systemd
    eudev
  ];

  # Combine Ubuntu libs with nixpkgs libs
  ubuntuLibPath = pkgs.lib.makeLibraryPath (builtins.attrValues ubuntuLibs);
  nixLibPath = pkgs.lib.makeLibraryPath playwrightDeps;

  shellHookContent = ''
    # Prepend Ubuntu 24.04 libraries, then Nix libraries
    export LD_LIBRARY_PATH="${ubuntuLibPath}:${nixLibPath}:$LD_LIBRARY_PATH"

    export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS="1"

    # Force Playwright to use Ubuntu 24.04 builds
    export PLAYWRIGHT_HOST_PLATFORM_OVERRIDE="ubuntu24.04-x64"

    # Prevent external browser opening for traces
    export BROWSER=none

    echo "✓ Playwright environment loaded (Ubuntu 24.04 + Nix)"
    echo "  Ubuntu libraries: ICU 74, libffi 8, libjpeg-turbo 8"
    echo "  Nix packages: ${toString (builtins.length playwrightDeps)} packages"
    echo ""
    echo "Usage:"
    echo "  npx playwright install    # Download browsers"
    echo "  npx playwright test       # Run tests"
  '';

in
pkgs.mkShell {
  buildInputs = playwrightDeps ++ [ patchWebkit pkgs.patchelf ];

  shellHook = shellHookContent + ''
    echo "  After installing: run 'patch-webkit' to fix library paths"
  '';

  # Expose attributes for child projects to import
  passthru = {
    inherit playwrightDeps ubuntuLibs ubuntuLibPath nixLibPath shellHookContent patchWebkit;
  };
}
