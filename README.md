# Labour Bureau

Local development and production infrastructure for Infinite Experiment.
Orchestration lives here; application code lives in sibling checkouts.

## Repository layout

Clone these repositories side by side:

```
infinite-experiment/
  labour-bureau/    # this repo — Compose, observability, launch scripts
  politburo/        # Go rewrite — API, jobs, and server-rendered UI in one binary
  comrade-bot/      # Discord bot
```

There is no monorepo root. Run Compose and scripts from `labour-bureau/`.

## Local development

### Prerequisites

- Docker (or Podman with `CONTAINER_CLI=podman`)
- Go 1.24+ (Politburo on the host)
- Node 20+ (comrade-bot on the host)
- tmux (for `start-dev.sh`)

### First-time setup

**1. Politburo environment**

```sh
cd ../politburo
cp .env.example .env
```

Edit `.env` for local work. Minimum useful settings:

| Variable | Typical local value | Notes |
|---|---|---|
| `PORT` | `8082` | Rewrite default |
| `PG_HOST` | `localhost` | Compose Postgres is published on the host |
| `PG_DB` | `politburo_next` | Isolated database for the rewrite |
| `JOBS_ENABLED` | `true` | Required for cache sync jobs |
| `IF_API_KEY` | your key | Required when jobs are enabled |

Use `PG_*` vars (or a `localhost` DSN) — not Compose hostname `db`, which only resolves inside Docker.

**2. Rewrite database**

Create the database and apply the baseline schema once:

```sh
cd labour-bureau
docker compose -f docker-compose.dev.yml up -d db

docker compose -f docker-compose.dev.yml exec -T db \
  psql -U ieuser -d postgres -c "CREATE DATABASE politburo_next;" \
  2>/dev/null || true

docker compose -f docker-compose.dev.yml exec -T db \
  psql -v ON_ERROR_STOP=1 -1 -U ieuser -d politburo_next \
  < ../politburo/migrations/000_infinite_schema.sql
```

See `../politburo/migrations/README.md` for migration policy.

**3. Comrade Bot**

```sh
cd ../comrade-bot
npm install
cp .env.example .env   # if present; otherwise create from prod template
```

Set `DISCORD_BOT_TOKEN`, `DISCORD_BOT_CLIENT_ID`, and `API_URL`. Default is `http://localhost:8080`; use `http://localhost:8082` when calling the rewrite API.

### Daily flow: `start-dev.sh`

From `labour-bureau/`:

```sh
./start-dev.sh
```

This attaches a tmux session `infinite-stage` (windows are 1-indexed in tmux):

| Window | Name | Purpose |
|---|---|---|
| 1 | `compose-up` | Backing services only — see [Compose services](#compose-services) |
| 2 | `comrade-bot` | `npm run dev` on the host (`ts-node-dev`) |
| 3 | `politburo` | Air hot reload on the host |

Prefer VS Code **Debug Politburo** over the tmux Politburo window when debugging.

Politburo logs are teed to `/tmp/politburo.log` for Promtail → Loki. Air loads `politburo/.env` via `env_files` in `.air.toml`.

Podman:

```sh
CONTAINER_CLI=podman ./start-dev.sh
```

### Compose services

`docker-compose.dev.yml` runs **backing services only**. Politburo and comrade-bot are intentionally excluded so `start-dev.sh` can run them on the host with live reload.

| Service | Host port | Notes |
|---|---|---|
| Postgres | `5432` | `ieuser` / `iepass`; DBs `infinite` and `politburo_next` |
| Redis | `6379` | No password in dev |
| pgAdmin | `5050` | Web UI for Postgres |
| Swagger UI | `8081` | Contract viewer; also via `make openapi-view` in politburo |
| Prometheus | `9090` | Scrapes host Politburo `:8082` and comrade-bot metrics `:9091` |
| Loki | `3100` | Log aggregation |
| Promtail | `9080` | Journal + `/tmp/politburo.log` |
| Grafana | `3000` | `admin` / `admin` |

### Host applications

| App | How it runs | Host port | Notes |
|---|---|---|---|
| Politburo (rewrite) | Air / IDE via `start-dev.sh` | `8082` (default) | API `/api/v1/...`, UI `/dashboard`, `/metrics` |
| comrade-bot | `npm run dev` via `start-dev.sh` | `9091` metrics | Reads `comrade-bot/.env` |

There is **no separate Vizburo application**. Dashboard and static assets ship inside the Politburo binary (`/dashboard`, `/static`).

### Compose without tmux

Bring up backing services only:

```sh
docker compose -f docker-compose.dev.yml up
```

Single service:

```sh
docker compose -f docker-compose.dev.yml up db
docker compose -f docker-compose.dev.yml logs -f db
```

Tear down:

```sh
docker compose -f docker-compose.dev.yml down
docker compose -f docker-compose.dev.yml down -v   # also remove volumes
```

Run Politburo and comrade-bot manually in separate terminals when not using tmux:

```sh
cd ../politburo && go tool -modfile=tools/go.mod air -c .air.toml
cd ../comrade-bot && npm run dev
```

### Politburo-only manual run

With Postgres and Redis already up:

```sh
cd ../politburo
cp .env.example .env
go run ./cmd/politburo
# or: go tool -modfile=tools/go.mod air -c .air.toml
```

Health checks:

```sh
curl http://localhost:8082/health/live
curl http://localhost:8082/health/ready
```

OpenAPI viewer from politburo:

```sh
make openapi-view    # http://localhost:8081
```

Further Politburo detail: `../politburo/README.md` and `../politburo/docs/`.

## Production

Production deploy and systemd setup live under `prod/`. See `prod/README.md` and `prod/SYSTEMD_SETUP.md`.
