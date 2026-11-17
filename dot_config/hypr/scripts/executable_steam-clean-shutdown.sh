#!/usr/bin/env bash

pgrep -x steam >/dev/null || exit 0

/usr/bin/steam -shutdown >/dev/null 2>&1 &

for _ in $(seq 30); do
  pgrep -x steam >/dev/null || exit 0
  sleep 1
done
exit 0
