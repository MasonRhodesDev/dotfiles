#!/bin/bash
# Wrapper installed at /usr/lib/systemd/system-sleep/hypr-power.
# systemd-suspend.service runs every executable in that directory with
# arguments: <pre|post> <suspend|hibernate|hybrid-sleep|suspend-then-hibernate>.
# We only care about pre/post; pass through.
exec /usr/local/bin/hypr-power sleep-hook "$1"
