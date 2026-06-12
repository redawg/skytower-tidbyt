# SkyTower Workspace

**Repo:** [redawg/skytower-tidbyt](https://github.com/redawg/skytower-tidbyt) — live flight dashboard for Tidbyt via OpenSky Network ADS-B data.

## Subagent

Invoke **`@skytower-agent`** (`.cursor/agents/skytower-agent.md`).

## Quick reference

| Item | Value |
|------|--------|
| **App** | Pixlet `skytower.star` → render WebP → Tidbyt push |
| **Data** | [OpenSky Network](https://opensky-network.org) (OAuth recommended) |
| **Deploy** | Podman `Containerfile` — see `CONTAINER.md` |
| **Entity** | Personal / household |
| **Fleet** | infra3 `.36` · container `skytower-tidbyt` · `:10005` reserved (no gateway) |
| **Run** | `a-schoenfeld-corp-workspace/scripts/run-skytower-tidbyt.sh --build --daemon` |

Open holding multi-root: `a-schoenfeld-corp-workspace/a-schoenfeld-holding.code-workspace` (includes **SkyTower** folder).

## Local run

```bash
cp .env.example .env   # Tidbyt + lat/lng + OpenSky OAuth
podman build -t skytower-tidbyt .
podman run --rm --env-file .env skytower-tidbyt
```

Dev preview: `pixlet serve skytower.star -w` (see `README.md`).
