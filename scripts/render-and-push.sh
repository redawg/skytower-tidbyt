#!/bin/bash
set -euo pipefail

APP_DIR="${APP_DIR:-/app}"
OUTPUT="${OUTPUT:-/tmp/skytower.webp}"
STAR="${APP_DIR}/skytower.star"

: "${TIDBYT_DEVICE_ID:?TIDBYT_DEVICE_ID is required}"
: "${TIDBYT_API_TOKEN:?TIDBYT_API_TOKEN is required}"
: "${LAT:?LAT is required}"
: "${LNG:?LNG is required}"

# shellcheck disable=SC1091
source /app/scripts/load-config.sh

MODE="${MODE:-dashboard}"
RADIUS="${RADIUS:-20}"
INSTALLATION_ID="${INSTALLATION_ID:-skytower}"
TRACK_CALLSIGN="${TRACK_CALLSIGN:-}"
OPENSKY_CLIENT_ID="${OPENSKY_CLIENT_ID:-}"
OPENSKY_CLIENT_SECRET="${OPENSKY_CLIENT_SECRET:-}"

echo "[skytower] pixlet check ${STAR}"
pixlet check "${STAR}"

echo "[skytower] pixlet render mode=${MODE} radius=${RADIUS} lat=${LAT} lng=${LNG} track=${TRACK_CALLSIGN:-—}"
render_args=(
    "lat=${LAT}"
    "lng=${LNG}"
    "radius=${RADIUS}"
    "mode=${MODE}"
    "client_id=${OPENSKY_CLIENT_ID}"
    "client_secret=${OPENSKY_CLIENT_SECRET}"
)
[[ -n "${TRACK_CALLSIGN}" ]] && render_args+=("track_callsign=${TRACK_CALLSIGN}")

pixlet render "${STAR}" "${render_args[@]}" -o "${OUTPUT}"

echo "[skytower] pixlet push device=${TIDBYT_DEVICE_ID} installation=${INSTALLATION_ID}"
pixlet push "${TIDBYT_DEVICE_ID}" "${OUTPUT}" \
    -t "${TIDBYT_API_TOKEN}" \
    -i "${INSTALLATION_ID}"

echo "[skytower] push complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
