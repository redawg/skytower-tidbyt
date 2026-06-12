#!/usr/bin/env python3
"""Bearer auth for internal fleet HTTP APIs (dt-agent-cron, CoCo notify, SkyTower config)."""

from __future__ import annotations

import json
import os
import secrets
from typing import Any


def api_token() -> str:
    return (
        os.environ.get("INTERNAL_API_TOKEN")
        or os.environ.get("MCP_CLIENT_TOKEN")
        or os.environ.get("MCP_AUTH_TOKEN")
        or ""
    ).strip()


def auth_required() -> bool:
    raw = (os.environ.get("INTERNAL_API_AUTH_REQUIRED") or "true").strip().lower()
    return raw not in ("0", "false", "no", "off")


def bind_host(default: str = "127.0.0.1") -> str:
    return (os.environ.get("HTTP_BIND_HOST") or default).strip() or default


def json_auth_error(message: str, status: int) -> bytes:
    return json.dumps({"status": "error", "message": message}).encode()


def validate_bearer(header: str | None) -> tuple[bool, str, int]:
    if not auth_required():
        return True, "ok", 200
    expected = api_token()
    if not expected:
        return False, "internal API token not configured", 503
    if not header or not header.strip():
        return False, "Authorization header required", 401
    parts = header.strip().split(None, 1)
    if len(parts) != 2 or parts[0].lower() != "bearer":
        return False, "Bearer token required", 401
    provided = parts[1].strip()
    if not provided or not secrets.compare_digest(provided, expected):
        return False, "Invalid bearer token", 403
    return True, "ok", 200


def auth_headers() -> dict[str, str]:
    token = api_token()
    if not token:
        return {}
    return {"Authorization": f"Bearer {token}"}


def reject_unless_authorized(handler: Any, *, exempt: bool = False) -> bool:
    """Return True if request may proceed."""
    if exempt:
        return True
    ok, msg, status = validate_bearer(handler.headers.get("Authorization"))
    if ok:
        return True
    body = json_auth_error(msg, status)
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)
    return False
