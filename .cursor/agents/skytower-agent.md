---
version: "1.0.0"
name: skytower-agent
description: >-
  SkyTower Tidbyt flight display — OpenSky ADS-B data, Pixlet render, Tidbyt push.
  Use for skytower.star, container deploy, OpenSky/Tidbyt config, and display modes
  (dashboard, tower, radar, route, track). Personal scope only.
model: inherit
---

# SkyTower Agent

## Application

**SkyTower** ([skytower-tidbyt](https://github.com/redawg/skytower-tidbyt)) renders a FlightWall-style live flight board on a [Tidbyt](https://tidbyt.com) using [OpenSky Network](https://opensky-network.org) data.

| Mode | Behavior |
|------|----------|
| `dashboard` | Auto-rotate tower / radar / route (default) |
| `tower` / `radar` / `route` | Single view |
| `track` | Follow one callsign |

## Workspace

- **Root:** `skytower-workspace/` (this repo)
- **Stack metadata:** `.cursor/data/skytower-stack.yaml` (holding repo)
- **Container:** `Containerfile` · `CONTAINER.md` · `scripts/render-and-push.sh`

## Configuration (never commit secrets)

| Variable | Required | Notes |
|----------|----------|-------|
| `TIDBYT_DEVICE_ID` | yes | Tidbyt device |
| `TIDBYT_API_TOKEN` | yes | Tidbyt API |
| `LAT` / `LNG` | yes | Observer location |
| `OPENSKY_CLIENT_ID` / `SECRET` | recommended | Avoid anonymous rate limits |
| `MODE` | no | default `dashboard` |
| `RADIUS` | no | miles, default 20 |
| `REFRESH_SECONDS` | no | default 60 |

Use `.env` from `.env.example`.

## MCP / delegation

This app talks to **OpenSky** and **Tidbyt APIs** directly — no fleet MCP required for core operation.

| Need | Delegate to |
|------|-------------|
| Podman on infra3, cron, Quay, gateway | `@redhat-agent` |
| Personal email / travel expenses | `@flight-tracker` / `@personal-agent` |
| Corp / DT / CDO work | `@holding-director` → entity agents |

## Fleet placement (infra3)

| Field | Value |
|-------|-------|
| Host | `172.16.1.36` (infra3) |
| Container | `skytower-tidbyt` |
| Reserved port | `:10005` (collision slot only — no host bind, no gateway) |

## Fleet run (from holding workstation)

```bash
a-schoenfeld-corp-workspace/scripts/run-skytower-tidbyt.sh --build --daemon
a-schoenfeld-corp-workspace/scripts/run-skytower-tidbyt.sh --once
```

Secrets: vault keys `tidbyt_api_token`, `tidbyt_device_id`, `opensky_client_id`, `opensky_client_secret` (see `.cursor/data/secrets-vault-schema.md`).
