# SkyTower Tidbyt container

Run the SkyTower Pixlet app in a Podman container based on RHEL UBI 10. The container installs `pixlet`, renders `skytower.star` with environment-driven config, and pushes WebP frames to your Tidbyt on a schedule or once.

## Build

From the project root:

```bash
podman build -t skytower-tidbyt .
```

Optional: pin a specific pixlet release at build time:

```bash
podman build --build-arg PIXLET_VERSION=v0.34.0 -t skytower-tidbyt .
```

## Configure

Copy the example env file and fill in your values (never commit real secrets):

```bash
cp .env.example .env
```

## Run

**Loop mode (default)** — check, render, and push every `REFRESH_SECONDS` (default 60):

```bash
podman run --rm --env-file .env skytower-tidbyt
```

**Once** — single check/render/push cycle, then exit:

```bash
podman run --rm --env-file .env -e RUN_ONCE=1 skytower-tidbyt
```

**Faster refresh (10s)** — fresher flight data, more API and Tidbyt traffic:

```bash
podman run --rm --env-file .env -e REFRESH_SECONDS=10 skytower-tidbyt
```

Override individual settings without editing `.env`:

```bash
podman run --rm \
  -e TIDBYT_DEVICE_ID=... \
  -e TIDBYT_API_TOKEN=... \
  -e LAT=37.6213 \
  -e LNG=-122.3790 \
  -e MODE=radar \
  -e RADIUS=25 \
  -e RUN_ONCE=1 \
  skytower-tidbyt
```

## Required environment variables

| Variable | Description |
|----------|-------------|
| `TIDBYT_DEVICE_ID` | Tidbyt device ID |
| `TIDBYT_API_TOKEN` | Tidbyt API token |
| `LAT` | Observer latitude |
| `LNG` | Observer longitude |

## Optional environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OPENSKY_CLIENT_ID` | *(empty)* | OpenSky OAuth client ID |
| `OPENSKY_CLIENT_SECRET` | *(empty)* | OpenSky OAuth client secret |
| `MODE` | `dashboard` | `dashboard`, `tower`, `radar`, `route`, or `track` |
| `RADIUS` | `20` | Search radius in miles |
| `INSTALLATION_ID` | `skytower` | Tidbyt installation ID for rotation |
| `REFRESH_SECONDS` | `60` | Loop interval (ignored when `RUN_ONCE=1`) |
| `RUN_ONCE` | `0` | Set to `1` to run once and exit |

## Refresh interval tradeoffs

| Interval | Pros | Cons |
|----------|------|------|
| **10s** | Near-real-time aircraft positions; smoother rotation on device | Higher OpenSky API usage (rate limits without OAuth); more Tidbyt pushes; more CPU/network in container |
| **60s** | Lower API load; gentler on Tidbyt push limits; fine for casual viewing | Aircraft positions can lag up to a minute |

OpenSky anonymous access is heavily rate-limited. Set `OPENSKY_CLIENT_ID` and `OPENSKY_CLIENT_SECRET` before using aggressive refresh intervals.

## Scripts

- `scripts/render-and-push.sh` — runs `pixlet check`, `pixlet render`, `pixlet push`
- `scripts/entrypoint.sh` — invokes render-and-push once or in a sleep loop

## Limitations

- Linux `amd64` only (pixlet binary arch matches container).
- Requires outbound HTTPS to OpenSky, Tidbyt API, and GitHub (at build time for pixlet download).
- Does not replace Tidbyt Community Apps server-side scheduling; this is self-hosted push automation.
- Podman on Windows typically runs via WSL2; build/run commands above assume a Linux shell with Podman installed.
