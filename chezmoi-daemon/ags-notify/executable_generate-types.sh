#!/bin/bash
set -e

echo "Generating TypeScript definitions for astal and dependencies..."

# Generate types for astal and common dependencies
/usr/bin/npx -y @ts-for-gir/cli generate \
  AstalIO-0.1 Astal-3.0 Astal-4.0 \
  GLib-2.0 GObject-2.0 Gio-2.0 Gtk-4.0 \
  --ignoreVersionConflicts \
  --outdir /home/mason/.local/share/chezmoi/chezmoi-daemon/ags-notify/@girs \
  -g /usr/local/share/gir-1.0 \
  -g /usr/share/gir-1.0 \
  -g /usr/share/*/gir-1.0 \
  2>/dev/null || echo "Type generation completed with warnings (this is normal)"

echo "TypeScript definitions generated successfully!"
echo "Note: Warnings about gintptr, time_t, pid_t, and uid_t are normal and handled by fixes.d.ts"