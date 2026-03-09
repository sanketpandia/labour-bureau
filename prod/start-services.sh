#!/bin/bash
# start-services.sh - Start all services individually using podman

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"

NETWORK_NAME="labour-bureau_internal"

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

# Start each service
"${SCRIPT_DIR}/scripts/start-db.sh"
"${SCRIPT_DIR}/scripts/start-redis.sh"
"${SCRIPT_DIR}/scripts/start-politburo.sh"
"${SCRIPT_DIR}/scripts/start-comrade-bot.sh"
"${SCRIPT_DIR}/scripts/start-node-exporter.sh"
"${SCRIPT_DIR}/scripts/start-prometheus.sh"
"${SCRIPT_DIR}/scripts/start-loki.sh"
"${SCRIPT_DIR}/scripts/start-promtail.sh"
"${SCRIPT_DIR}/scripts/start-grafana.sh"

# Start log shipper systemd service if not running
if ! systemctl is-active --quiet podman-log-shipper.service 2>/dev/null; then
    echo "📝 Starting Podman Log Shipper service..."
    sudo systemctl start podman-log-shipper.service 2>/dev/null || echo "  Note: Install service with: sudo systemctl enable --now $(realpath ${SCRIPT_DIR}/podman-log-shipper.service)"
fi

echo -e "\n${GREEN}✅ All services started!${NC}"
echo ""
echo "📊 Service Status:"
podman ps --filter "name=db\|redis\|politburo\|comrade-bot\|node-exporter\|prometheus\|loki\|promtail\|grafana" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
