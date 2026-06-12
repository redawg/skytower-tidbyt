#!/bin/bash
set -euo pipefail

REFRESH_SECONDS="${REFRESH_SECONDS:-60}"
RUN_ONCE="${RUN_ONCE:-0}"

run_cycle() {
    /app/scripts/render-and-push.sh
}

case "${RUN_ONCE}" in
    1|true|yes|TRUE|YES)
        run_cycle
        exit 0
        ;;
esac

if [[ "${REFRESH_SECONDS}" -lt 1 ]]; then
    echo "REFRESH_SECONDS must be >= 1 in loop mode (or set RUN_ONCE=1)" >&2
    exit 1
fi

CONFIG_PORT="${CONFIG_PORT:-10005}"
if [[ -f /app/scripts/config-server.py ]]; then
    echo "[skytower] config UI http://0.0.0.0:${CONFIG_PORT} (file: ${SKYTOWER_CONFIG_FILE:-/data/config.json})"
    python3 /app/scripts/config-server.py &
fi

echo "[skytower] loop mode: refresh every ${REFRESH_SECONDS}s (RUN_ONCE=1 for single run)"

while true; do
    if ! run_cycle; then
        echo "[skytower] cycle failed; retrying in ${REFRESH_SECONDS}s" >&2
    fi
    sleep "${REFRESH_SECONDS}"
done
