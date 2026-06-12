# SkyTower

FlightWall-style live flight dashboard for [Tidbyt](https://tidbyt.com), powered by open [OpenSky Network](https://opensky-network.org) ADS-B data.

## Features

- **Area mode** — closest aircraft within a configurable radius
- **Track mode** — follow a single callsign
- **Dashboard mode** — auto-rotates tower, radar, and route views every 10 seconds
- **Metrics** — altitude, speed, track, vertical rate (toggle each)
- **Container deploy** — Podman image on RHEL UBI 10 for scheduled render/push

## Quick start

Install [Pixlet](https://tidbyt.dev/docs/build/installing-pixlet), then:

```bash
pixlet serve skytower.star -w
```

Open `http://127.0.0.1:8080` with query params for lat, lng, OpenSky credentials, and mode.

Render and push to your Tidbyt:

```bash
pixlet render skytower.star lat=YOUR_LAT lng=YOUR_LNG mode=dashboard client_id=YOUR_ID client_secret=YOUR_SECRET
pixlet push --installation-id skytower YOUR_DEVICE_ID skytower.webp
```

## Container

See [CONTAINER.md](CONTAINER.md) for Podman build/run on RHEL UBI 10.

```bash
cp .env.example .env   # fill in Tidbyt token, device ID, lat/lng
podman build -t skytower-tidbyt .
podman run --rm --env-file .env skytower-tidbyt
```

## Configuration

| Setting | Description |
|---------|-------------|
| `lat` / `lng` | Observer location |
| `radius` | Search radius in miles (default 20) |
| `mode` | `dashboard`, `tower`, `radar`, `route`, or `track` |
| `client_id` / `client_secret` | OpenSky OAuth (free at opensky-network.org/account/request) |

Never commit real API tokens or secrets. Use `.env` locally (see `.env.example`).
