#!/bin/bash
# start-grafana.sh - Start Grafana monitoring dashboard service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENV_DIR="${SCRIPT_DIR}/../env"
NETWORK_NAME="labour-bureau_internal"
CONTAINER_NAME="grafana"

echo -e "${GREEN}📈 Starting Grafana...${NC}"

# Get Grafana password from env file
if [ -f "${ENV_DIR}/monitoring.env" ]; then
    GRAFANA_PASSWORD=$(grep "^GRAFANA_ADMIN_PASSWORD=" "${ENV_DIR}/monitoring.env" | sed 's/^GRAFANA_ADMIN_PASSWORD=//' | tr -d '"')
else
    GRAFANA_PASSWORD="admin"
fi

if container_exists "$CONTAINER_NAME"; then
    if ! container_running "$CONTAINER_NAME"; then
        echo "  Starting existing container..."
        podman start "$CONTAINER_NAME"
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p 127.0.0.1:3000:3000 \
        --env-file "${ENV_DIR}/monitoring.env" \
        -e GF_SECURITY_ADMIN_PASSWORD="${GRAFANA_PASSWORD}" \
        -e GF_SECURITY_ADMIN_USER=admin \
        -e GF_INSTALL_PLUGINS=grafana-worldmap-panel \
        -e GF_SERVER_ROOT_URL=https://monitor.comradebot.cc \
        -e GF_SERVER_DOMAIN=monitor.comradebot.cc \
        -e GF_SERVER_ALLOWED_ORIGINS="https://monitor.comradebot.cc" \
        -e GF_SECURITY_COOKIE_SECURE="true" \
        -e GF_SECURITY_COOKIE_SAMESITE="none" \
        -e GF_SECURITY_ALLOW_EMBEDDING="true" \
        -e GF_USERS_ALLOW_SIGN_UP="false" \
        -e GF_LOG_LEVEL=warn \
        -e GF_ANALYTICS_REPORTING_ENABLED="false" \
        -e GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
        -v labour-bureau_grafana-storage:/var/lib/grafana \
        -v "${SCRIPT_DIR}/../grafana/provisioning/datasources:/etc/grafana/provisioning/datasources:ro" \
        -v "${SCRIPT_DIR}/../grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards:ro" \
        --restart unless-stopped \
        docker.io/grafana/grafana:latest
fi