#!/usr/bin/env bash
# Cleanly shut down Steam during session teardown.
# Invoked as ExecStop= of steam-clean-shutdown.service: runs before app scopes
# get SIGTERM (see app-.scope.d drop-in), because SIGTERM makes Steam's CEF
# record an unclean exit -> "runtime detect" can disable web view GPU accel
# -> laggy Big Picture/overlay.

pgrep -x steam >/dev/null || exit 0

/usr/bin/steam -shutdown >/dev/null 2>&1 &

# Wait for Steam to fully exit; give up after 30s and let the normal
# scope TERM/KILL handle whatever is left.
for _ in $(seq 30); do
  pgrep -x steam >/dev/null || exit 0
  sleep 1
done
exit 0
