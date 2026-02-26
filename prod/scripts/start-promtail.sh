#!/bin/bash
# start-promtail.sh - Start Promtail log shipper service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

NETWORK_NAME="labour-bureau_internal"
CONTAINER_NAME="promtail"

echo -e "${GREEN}📤 Starting Promtail...${NC}"

if container_exists "$CONTAINER_NAME"; then
    if ! container_running "$CONTAINER_NAME"; then
        echo "  Starting existing container..."
        podman start "$CONTAINER_NAME"
    else
        echo "  Already running"
    fi
else
    echo "  Creating new container..."
    # For Podman, we use file-based logging instead of Docker socket
    podman run -d \
        --name "$CONTAINER_NAME" \
        --network "$NETWORK_NAME" \
        -p 9080:9080 \
        -v "${SCRIPT_DIR}/../promtail-config.yml:/etc/promtail/config.yml:ro" \
        -v /var/log:/var/log:ro \
        --restart unless-stopped \
        docker.io/grafana/promtail:latest \
        -config.file=/etc/promtail/config.yml
fi
