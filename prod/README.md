# Production Deployment Guide

This directory contains all production deployment configuration files for the Infinite Experiment stack.

## Directory Structure

```
prod/
├── docker-compose.prod.yml          # Main production compose file
├── Caddyfile                        # Caddy reverse proxy config
├── prometheus.prod.yml              # Prometheus config
├── loki.prod.yml                    # Loki config
├── promtail-config.yml              # Promtail config
├── grafana/                         # Grafana provisioning
│   └── provisioning/
│       ├── dashboards/
│       └── datasources/
├── env/                             # Environment variable templates
│   ├── politburo.env.example
│   ├── comrade-bot.env.example
│   ├── database.env.example
│   ├── cache.env.example
│   └── monitoring.env.example
└── README.md                        # This file
```

## Initial Setup

### 1. Create Environment Files

Copy each `.example` file to create the actual environment files (without `.example`):

```bash
cd prod/env
cp politburo.env.example politburo.env
cp comrade-bot.env.example comrade-bot.env
cp database.env.example database.env
cp cache.env.example cache.env
cp monitoring.env.example monitoring.env
```

### 2. Generate Secure Secrets

**Generate strong passwords for each service:**

```bash
# PostgreSQL password
openssl rand -base64 32

# Redis password
openssl rand -base64 32

# JWT secret
openssl rand -base64 32

# Grafana admin password
openssl rand -base64 32
```

### 3. Configure Environment Files

Edit each `.env` file and replace all `CHANGE_ME` values with your generated secrets:

- **`database.env`**: Set `POSTGRES_PASSWORD`
- **`cache.env`**: Set `REDIS_PASSWORD`
- **`politburo.env`**: Set `PG_PASSWORD`, `REDIS_PASSWORD`, `IF_API_KEY`, `GOD_MODE`, `JWT_SECRET`
- **`comrade-bot.env`**: Set `BOT_TOKEN` (Discord bot token)
- **`monitoring.env`**: Set `GRAFANA_ADMIN_PASSWORD`

### 4. Configure Docker to Use Mounted Disk for Volumes

To store all Docker volumes (including PostgreSQL data) on your mounted disk (`/mnt/HC_Volume_104770220`), configure Docker's data-root:

**Create Docker configuration directory:**
```bash
sudo mkdir -p /etc/docker
```

**Create or edit `/etc/docker/daemon.json`:**
```bash
sudo nano /etc/docker/daemon.json
```

**Add the following configuration:**
```json
{
  "data-root": "/mnt/HC_Volume_104770220/docker"
}
```

**Restart Docker:**
```bash
sudo systemctl restart docker
```

**Verify the configuration:**
```bash
docker info | grep "Docker Root Dir"
```

This should show: `Docker Root Dir: /mnt/HC_Volume_104770220/docker`

**Note:** After changing the data-root, existing volumes will need to be migrated or recreated. If you have existing volumes, you may need to:
1. Stop all containers: `docker-compose down`
2. Backup existing volumes (if any)
3. Restart Docker with new data-root
4. Recreate volumes: `docker-compose up -d`

### 5. Security Notes

⚠️ **IMPORTANT**: 
- Never commit actual `.env` files to git (they should be in `.gitignore`)
- Keep `.env.example` files as templates only
- Use strong, unique passwords for each service
- Restrict file permissions: `chmod 600 prod/env/*.env`

## Deployment

### Start the Stack

From the `labour-bureau` directory:

```bash
docker-compose -f prod/docker-compose.prod.yml up -d
```

### Check Service Status

```bash
docker-compose -f prod/docker-compose.prod.yml ps
```

### View Logs

```bash
# All services
docker-compose -f prod/docker-compose.prod.yml logs -f

# Specific service
docker-compose -f prod/docker-compose.prod.yml logs -f politburo
```

### Stop the Stack

```bash
docker-compose -f prod/docker-compose.prod.yml down
```

### Stop and Remove Volumes (⚠️ Destroys Data)

```bash
docker-compose -f prod/docker-compose.prod.yml down -v
```

## Service Access

- **Politburo API**: Accessible via Caddy at `https://comradebot.cc`
- **Grafana**: Accessible via Caddy at `https://monitor.comradebot.cc`
- **Prometheus**: Internal only (port 9090, not exposed)
- **Loki**: Internal only (port 3100, not exposed)
- **Promtail**: Internal only (port 9080, not exposed)

## Environment Variable Organization

Environment variables are organized by service type to prevent unnecessary secret sharing:

- **`politburo.env`**: Politburo application configuration (database, Redis, API keys, security)
- **`comrade-bot.env`**: Comrade-bot configuration (Discord token, API URL)
- **`database.env`**: PostgreSQL database credentials
- **`cache.env`**: Redis cache password
- **`monitoring.env`**: Grafana admin password

Each service only receives the environment variables it needs, improving security isolation.

## Troubleshooting

### Docker Data Root Issues

If Docker volumes aren't being created on the mounted disk:

1. Verify Docker data-root configuration:
   ```bash
   docker info | grep "Docker Root Dir"
   ```

2. Ensure the directory exists and has proper permissions:
   ```bash
   sudo mkdir -p /mnt/HC_Volume_104770220/docker
   sudo chown -R root:root /mnt/HC_Volume_104770220/docker
   ```

3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```

### Redis Authentication Errors

Ensure `REDIS_PASSWORD` in `cache.env` matches the password used in `politburo.env`.

### Service Health Checks

Check service health:

```bash
docker-compose -f prod/docker-compose.prod.yml ps
```

All services should show "healthy" status.

### View Service Logs

```bash
# Politburo logs
docker-compose -f prod/docker-compose.prod.yml logs politburo

# Database logs
docker-compose -f prod/docker-compose.prod.yml logs db

# All logs
docker-compose -f prod/docker-compose.prod.yml logs
```

## Backup Recommendations

### PostgreSQL Backup

```bash
docker-compose -f prod/docker-compose.prod.yml exec db pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > backup.sql
```

### Redis Backup

Redis data is persisted via AOF (Append Only File) in the `redis-prod` volume.

## Updates

To update the stack:

```bash
# Pull latest images
docker-compose -f prod/docker-compose.prod.yml pull

# Rebuild and restart
docker-compose -f prod/docker-compose.prod.yml up -d --build
```
