#!/bin/bash
# deploy-politburo.sh - Deploy Politburo service (stop, rebuild, restart)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENV_DIR="${SCRIPT_DIR}/../env"
NETWORK_NAME="labour-bureau_internal"
POLITBURO_CONTAINER_NAME="politburo"
POLITBURO_IMAGE="politburo:latest"

echo -e "${GREEN}🚀 Deploying Politburo...${NC}"

# Stop container if running
if container_running "$POLITBURO_CONTAINER_NAME"; then
    echo "  Stopping container..."
    podman stop "$POLITBURO_CONTAINER_NAME"
fi

# Remove container if it exists
if container_exists "$POLITBURO_CONTAINER_NAME"; then
    echo "  Removing container..."
    podman rm "$POLITBURO_CONTAINER_NAME"
fi

# Optionally remove old image (uncomment to force clean rebuild)
# echo "  Removing old image..."
# podman rmi "$POLITBURO_IMAGE" 2>/dev/null || true

# Build new image
echo "  Building new image..."
podman build -t "$POLITBURO_IMAGE" -f "${SCRIPT_DIR}/../../../politburo/Dockerfile" "${SCRIPT_DIR}/../../../politburo"

# Create and start new container
echo "  Creating and starting container..."
podman run -d \
    --name "$POLITBURO_CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --network-alias "$POLITBURO_CONTAINER_NAME" \
    --env-file "${ENV_DIR}/politburo.env" \
    -p 127.0.0.1:8080:8080 \
    --restart unless-stopped \
    --health-cmd "wget --spider --quiet http://localhost:8080/healthCheck || exit 1" \
    --health-interval 30s \
    --health-timeout 5s \
    --health-retries 3 \
    "$POLITBURO_IMAGE"

echo -e "${GREEN}✅ Politburo deployed successfully!${NC}"
