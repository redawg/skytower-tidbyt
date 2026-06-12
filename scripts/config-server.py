#!/usr/bin/env python3
"""SkyTower config UI + API on :10005 — shares /data/config.json with fleet dashboard."""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

from internal_service_auth import bind_host, reject_unless_authorized

CONFIG_PATH = Path(os.environ.get("SKYTOWER_CONFIG_FILE", "/data/config.json"))
CONFIG_PORT = int(os.environ.get("CONFIG_PORT", "10005"))
VALID_MODES = ("dashboard", "tower", "radar", "route", "track")


def _defaults() -> dict:
    return {
        "lat": float(os.environ.get("LAT", "47.6319")),
        "lng": float(os.environ.get("LNG", "-121.9662")),
        "radius": int(os.environ.get("RADIUS", "20")),
        "mode": os.environ.get("MODE", "dashboard"),
        "track_callsign": os.environ.get("TRACK_CALLSIGN", ""),
    }


def load_config() -> dict:
    if CONFIG_PATH.is_file():
        try:
            data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return {**_defaults(), **data}
        except (OSError, json.JSONDecodeError, ValueError, TypeError):
            pass
    return _defaults()


def validate_payload(body: dict) -> dict:
    if not isinstance(body, dict):
        raise ValueError("body must be a JSON object")
    out = load_config()
    if "lat" in body:
        out["lat"] = float(body["lat"])
    if "lng" in body:
        out["lng"] = float(body["lng"])
    if "radius" in body:
        radius = int(body["radius"])
        if radius < 1 or radius > 150:
            raise ValueError("radius must be 1–150")
        out["radius"] = radius
    if "mode" in body:
        mode = str(body["mode"]).strip().lower()
        if mode not in VALID_MODES:
            raise ValueError(f"mode must be one of: {', '.join(VALID_MODES)}")
        out["mode"] = mode
    if "track_callsign" in body:
        out["track_callsign"] = str(body["track_callsign"]).strip().upper()
    out["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    out["updated_by"] = str(body.get("updated_by") or "container-ui")
    return out


def save_config(data: dict) -> dict:
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    return data


def html_page(cfg: dict) -> str:
    modes = "".join(
        f'<option value="{m}"{" selected" if cfg["mode"] == m else ""}>{m}</option>'
        for m in VALID_MODES
    )
    return f"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SkyTower Config</title>
<style>
body{{font-family:system-ui,sans-serif;background:#0f1419;color:#e7ecf3;margin:0;padding:1.25rem}}
.card{{max-width:28rem;background:#1a2332;border:1px solid #2d3a4f;border-radius:10px;padding:1rem}}
label{{display:block;font-size:.75rem;color:#8b9cb3;margin:.65rem 0 .2rem}}
input,select{{width:100%;padding:.45rem .55rem;border-radius:6px;border:1px solid #2d3a4f;background:#141c27;color:#e7ecf3}}
button{{margin-top:1rem;padding:.5rem 1rem;border:0;border-radius:6px;background:#6eb5ff;color:#0f1419;font-weight:600;cursor:pointer}}
.msg{{margin-top:.75rem;font-size:.8rem;color:#3dd68c}}
a{{color:#6eb5ff}}
</style></head><body>
<div class="card">
<h1 style="font-size:1.05rem;margin:0 0 .25rem">SkyTower Tidbyt</h1>
<p style="font-size:.8rem;color:#8b9cb3;margin:0 0 .5rem">Observer location &amp; display mode · saved to shared fleet config</p>
<form id="f">
<label>Latitude</label><input name="lat" type="number" step="any" value="{cfg['lat']}" required>
<label>Longitude</label><input name="lng" type="number" step="any" value="{cfg['lng']}" required>
<label>Radius (miles)</label><input name="radius" type="number" min="1" max="150" value="{cfg['radius']}" required>
<label>Mode</label><select name="mode">{modes}</select>
<label>Track callsign (track mode)</label><input name="track_callsign" value="{cfg.get('track_callsign','')}" placeholder="UAL123">
<button type="submit">Save</button>
<p class="msg" id="msg"></p>
</form>
<p style="font-size:.72rem;color:#8b9cb3;margin-top:1rem">Fleet dashboard: <a href="http://aatom.theschoenfelds.dom/skytower">/skytower</a></p>
</div>
<script>
document.getElementById('f').onsubmit=async(e)=>{{
 e.preventDefault();
 const fd=new FormData(e.target);
 const body=Object.fromEntries(fd.entries());
 body.radius=Number(body.radius); body.lat=Number(body.lat); body.lng=Number(body.lng);
 const r=await fetch('/api/config',{{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify(body)}});
 const j=await r.json();
 document.getElementById('msg').textContent=r.ok?'Saved — next push uses new settings.':(j.detail||'Save failed');
}};
</script></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _html(self, code: int, content: str) -> None:
        body = content.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path in ("/health", "/api/health"):
            self._json(200, {"status": "ok", "service": "skytower-tidbyt-config"})
            return
        if path == "/api/config":
            self._json(200, load_config())
            return
        if path in ("/", "/config"):
            self._html(200, html_page(load_config()))
            return
        self._json(404, {"detail": "not found"})

    def do_POST(self) -> None:
        if urlparse(self.path).path != "/api/config":
            self._json(404, {"detail": "not found"})
            return
        if not reject_unless_authorized(self):
            return
        length = int(self.headers.get("Content-Length", "0"))
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
            saved = save_config(validate_payload(body))
            self._json(200, saved)
        except (ValueError, json.JSONDecodeError) as exc:
            self._json(400, {"detail": str(exc)})


def main() -> None:
    host = bind_host()
    server = ThreadingHTTPServer((host, CONFIG_PORT), Handler)
    print(f"[skytower] config server http://{host}:{CONFIG_PORT} file={CONFIG_PATH}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
