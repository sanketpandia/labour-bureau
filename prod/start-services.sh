#!/bin/bash
# start-services.sh - Start all services individually using podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="${SCRIPT_DIR}/env"
NETWORK_NAME="labour-bureau_internal"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Labour Bureau Services${NC}"

# Create network if it doesn't exist
if ! podman network exists "$NETWORK_NAME" 2>/dev/null; then
    echo "📡 Creating network: $NETWORK_NAME"
    podman network create "$NETWORK_NAME"
fi

# Create volumes if they don't exist
echo "💾 Ensuring volumes exist..."
podman volume inspect labour-bureau_pgdata-prod >/dev/null 2>&1 || podman volume create labour-bureau_pgdata-prod
podman volume inspect labour-bureau_redis-prod >/dev/null 2>&1 || podman volume create labour-bureau_redis-prod
podman volume inspect labour-bureau_prometheus-storage >/dev/null 2>&1 || podman volume create labour-bureau_prometheus-storage
podman volume inspect labour-bureau_loki-storage >/dev/null 2>&1 || podman volume create labour-bureau_loki-storage
podman volume inspect labour-bureau_grafana-storage >/dev/null 2>&1 || podman volume create labour-bureau_grafana-storage

# Function to check if container exists and is running
container_exists() {
    podman ps -a --format "{{.Names}}" | grep -q "^${1}$"
}

container_running() {
    podman ps --format "{{.Names}}" | grep -q "^${1}$"
}

# Start PostgreSQL
echo -e "\n${GREEN}🗄️  Starting PostgreSQL...${NC}"
if container_exists "labour-bureau_db_1"; then
    if ! container_running "labour-bureau_db_1"; then
        echo "  Starting existing container..."
        podman start labour-bureau_db_1
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name labour-bureau_db_1 \
        --network "$NETWORK_NAME" \
        --env-file "${ENV_DIR}/database.env" \
        -v labour-bureau_pgdata-prod:/var/lib/postgresql/data \
        -v "${SCRIPT_DIR}/../../politburo/infra/db/migrations:/migrations" \
        --restart unless-stopped \
        --health-cmd "pg_isready -U ieuser -d infinite" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 5 \
        docker.io/library/postgres:15
fi

# Wait for database to be ready
echo "  Waiting for database to be ready..."
sleep 5
for i in {1..30}; do
    if podman exec labour-bureau_db_1 pg_isready -U ieuser -d infinite >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Database is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "  ${RED}✗ Database failed to start${NC}"
        exit 1
    fi
    sleep 1
done

# Start Redis
echo -e "\n${GREEN}🔴 Starting Redis...${NC}"
# Get Redis password from env file
if [ -f "${ENV_DIR}/cache.env" ]; then
    REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" "${ENV_DIR}/cache.env" | sed 's/^REDIS_PASSWORD=//' | tr -d '"')
else
    echo -e "  ${RED}✗ Error: cache.env not found${NC}"
    exit 1
fi

if container_exists "redis-prod"; then
    if ! container_running "redis-prod"; then
        echo "  Starting existing container..."
        podman start redis-prod
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name redis-prod \
        --network "$NETWORK_NAME" \
        --env-file "${ENV_DIR}/cache.env" \
        -v labour-bureau_redis-prod:/data \
        --restart unless-stopped \
        --health-cmd "sh -c \"redis-cli --raw -a '${REDIS_PASSWORD}' incr ping\"" \
        --health-interval 10s \
        --health-timeout 3s \
        --health-retries 5 \
        docker.io/library/redis:7-alpine \
        sh -c "redis-server --appendonly yes --requirepass '${REDIS_PASSWORD}'"
fi

# Start Politburo
echo -e "\n${GREEN}🏛️  Starting Politburo...${NC}"
if container_exists "labour-bureau_politburo_1"; then
    if ! container_running "labour-bureau_politburo_1"; then
        echo "  Starting existing container..."
        podman start labour-bureau_politburo_1
    else
        echo "  Already running"
    fi
else
    echo "  Building and creating new container..."
    # Build image first
    podman build -t labour-bureau_politburo:latest -f "${SCRIPT_DIR}/../../politburo/Dockerfile" "${SCRIPT_DIR}/../../politburo"
    
    podman run -d \
        --name labour-bureau_politburo_1 \
        --network "$NETWORK_NAME" \
        --env-file "${ENV_DIR}/politburo.env" \
        -p 127.0.0.1:8080:8080 \
        --restart unless-stopped \
        --health-cmd "wget --spider --quiet http://localhost:8080/healthCheck || exit 1" \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        labour-bureau_politburo:latest
fi

# Start Comrade Bot
echo -e "\n${GREEN}🤖 Starting Comrade Bot...${NC}"
if container_exists "labour-bureau_comrade-bot_1"; then
    if ! container_running "labour-bureau_comrade-bot_1"; then
        echo "  Starting existing container..."
        podman start labour-bureau_comrade-bot_1
    else
        echo "  Already running"
    fi
else
    echo "  Building and creating new container..."
    # Build image first
    podman build -t labour-bureau_comrade-bot:latest -f "${SCRIPT_DIR}/../../comrade-bot/Dockerfile" "${SCRIPT_DIR}/../../comrade-bot"
    
    # Get DISCORD_BOT_TOKEN from env file (or BOT_TOKEN as fallback)
    if [ -f "${ENV_DIR}/comrade-bot.env" ]; then
        DISCORD_BOT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" "${ENV_DIR}/comrade-bot.env" | sed 's/^DISCORD_BOT_TOKEN=//' | tr -d '"')
        # Fallback to BOT_TOKEN if DISCORD_BOT_TOKEN not found
        if [ -z "$DISCORD_BOT_TOKEN" ]; then
            DISCORD_BOT_TOKEN=$(grep "^BOT_TOKEN=" "${ENV_DIR}/comrade-bot.env" | sed 's/^BOT_TOKEN=//' | tr -d '"')
        fi
        if [ -z "$DISCORD_BOT_TOKEN" ]; then
            echo -e "  ${RED}✗ Error: DISCORD_BOT_TOKEN or BOT_TOKEN not found in comrade-bot.env${NC}"
            exit 1
        fi
    else
        echo -e "  ${RED}✗ Error: comrade-bot.env not found${NC}"
        exit 1
    fi
    
    podman run -d \
        --name labour-bureau_comrade-bot_1 \
        --network "$NETWORK_NAME" \
        --env-file "${ENV_DIR}/comrade-bot.env" \
        -e DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN}" \
        --restart unless-stopped \
        labour-bureau_comrade-bot:latest
fi

# Start Prometheus
echo -e "\n${GREEN}📊 Starting Prometheus...${NC}"
if container_exists "prometheus"; then
    if ! container_running "prometheus"; then
        echo "  Starting existing container..."
        podman start prometheus
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name prometheus \
        --network "$NETWORK_NAME" \
        -p 9090:9090 \
        -v "${SCRIPT_DIR}/prometheus.prod.yml:/etc/prometheus/prometheus.yml:ro" \
        -v labour-bureau_prometheus-storage:/prometheus \
        --restart unless-stopped \
        docker.io/prom/prometheus:latest \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --storage.tsdb.retention.time=30d
fi

# Start Loki
echo -e "\n${GREEN}📝 Starting Loki...${NC}"
if container_exists "loki"; then
    if ! container_running "loki"; then
        echo "  Starting existing container..."
        podman start loki
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name loki \
        --network "$NETWORK_NAME" \
        -p 3100:3100 \
        -v "${SCRIPT_DIR}/loki.prod.yml:/etc/loki/local-config.yml:ro" \
        -v labour-bureau_loki-storage:/loki \
        --restart unless-stopped \
        docker.io/grafana/loki:latest \
        -config.file=/etc/loki/local-config.yml
fi

# Start Promtail
echo -e "\n${GREEN}📤 Starting Promtail...${NC}"
if container_exists "promtail"; then
    if ! container_running "promtail"; then
        echo "  Starting existing container..."
        podman start promtail
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    # For Podman, we use file-based logging instead of Docker socket
    podman run -d \
        --name promtail \
        --network "$NETWORK_NAME" \
        -p 9080:9080 \
        -v "${SCRIPT_DIR}/promtail-config.yml:/etc/promtail/config.yml:ro" \
        -v /var/log:/var/log:ro \
        --restart unless-stopped \
        docker.io/grafana/promtail:latest \
        -config.file=/etc/promtail/config.yml
fi

# Start Grafana
echo -e "\n${GREEN}📈 Starting Grafana...${NC}"
# Get Grafana password from env file
if [ -f "${ENV_DIR}/monitoring.env" ]; then
    GRAFANA_PASSWORD=$(grep "^GRAFANA_ADMIN_PASSWORD=" "${ENV_DIR}/monitoring.env" | sed 's/^GRAFANA_ADMIN_PASSWORD=//' | tr -d '"')
else
    GRAFANA_PASSWORD="admin"
fi

if container_exists "grafana"; then
    if ! container_running "grafana"; then
        echo "  Starting existing container..."
        podman start grafana
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name grafana \
        --network "$NETWORK_NAME" \
        -p 127.0.0.1:3000:3000 \
        --env-file "${ENV_DIR}/monitoring.env" \
        -e GF_SECURITY_ADMIN_PASSWORD="${GRAFANA_PASSWORD}" \
        -e GF_SECURITY_ADMIN_USER=admin \
        -e GF_INSTALL_PLUGINS=grafana-worldmap-panel \
        -e GF_SERVER_ROOT_URL=https://monitor.comradebot.cc \
        -e GF_SERVER_DOMAIN=monitor.comradebot.cc \
        -e GF_SECURITY_COOKIE_SECURE="true" \
        -e GF_USERS_ALLOW_SIGN_UP="false" \
        -e GF_LOG_LEVEL=warn \
        -e GF_ANALYTICS_REPORTING_ENABLED="false" \
        -e GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
        -v labour-bureau_grafana-storage:/var/lib/grafana \
        -v "${SCRIPT_DIR}/grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro" \
        -v "${SCRIPT_DIR}/grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro" \
        --restart unless-stopped \
        docker.io/grafana/grafana:latest
fi

echo -e "\n${GREEN}✅ All services started!${NC}"
echo ""
echo "📊 Service Status:"
podman ps --filter "name=labour-bureau\|redis-prod\|prometheus\|loki\|promtail\|grafana" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
