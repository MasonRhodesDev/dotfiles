#!/bin/bash

# Launch Vivaldi with hardware acceleration enabled
/usr/bin/vivaldi-stable \
  --enable-gpu-rasterization \
  --enable-zero-copy \
  --enable-hardware-overlays \
  --ignore-gpu-blocklist \
  --disable-gpu-driver-bug-workarounds \
  "$@" 