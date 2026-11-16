#!/usr/bin/env bash
set -euo pipefail

"$1" gui &
pid=$!
trap 'kill -KILL "$pid" 2>/dev/null || true' EXIT
for ((i = 0; i < 30; ++i)); do
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "COLMAP GUI exited before displaying a window" >&2
        wait "$pid" || true
        exit 1
    fi
    if xdotool search --onlyvisible --name 'COLMAP' > /dev/null 2>&1; then
        echo "COLMAP GUI window is visible on the virtual display"
        exit 0
    fi
    sleep 1
done
echo "COLMAP GUI window did not appear" >&2
exit 1
