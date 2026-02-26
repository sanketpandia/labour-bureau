#!/bin/bash
# start-prometheus.sh - Start Prometheus monitoring service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

NETWORK_NAME="labour-bureau_internal"
CONTAINER_NAME="prometheus"

echo -e "${GREEN}📊 Starting Prometheus...${NC}"

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
        -p 9090:9090 \
        -v "${SCRIPT_DIR}/../prometheus.prod.yml:/etc/prometheus/prometheus.yml:ro" \
        -v labour-bureau_prometheus-storage:/prometheus \
        --restart unless-stopped \
        docker.io/prom/prometheus:latest \
        --config.file=/etc/prometheus/prometheus.yml \
        --storage.tsdb.path=/prometheus \
        --storage.tsdb.retention.time=30d
fi
