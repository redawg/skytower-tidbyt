#!/bin/bash
# Merge shared JSON config into env vars used by render-and-push.sh
set -euo pipefail

CONFIG="${SKYTOWER_CONFIG_FILE:-/data/config.json}"

if [[ ! -f "$CONFIG" ]]; then
  return 0 2>/dev/null || exit 0
fi

eval "$(python3 - <<'PY'
import json, os, shlex
path = os.environ.get("SKYTOWER_CONFIG_FILE", "/data/config.json")
try:
    with open(path, encoding="utf-8") as f:
        cfg = json.load(f)
except (OSError, json.JSONDecodeError):
    raise SystemExit(0)
if not isinstance(cfg, dict):
    raise SystemExit(0)
mapping = {
    "lat": "LAT",
    "lng": "LNG",
    "radius": "RADIUS",
    "mode": "MODE",
    "track_callsign": "TRACK_CALLSIGN",
}
for src, dst in mapping.items():
    val = cfg.get(src)
    if val is None or val == "":
        continue
    print(f"export {dst}={shlex.quote(str(val))}")
PY
)"
