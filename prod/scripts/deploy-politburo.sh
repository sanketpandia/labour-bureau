#!/bin/bash
# deploy-politburo.sh - Deploy Politburo service (stop, rebuild, restart)
# Usage: ./deploy-politburo.sh [--clean]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENV_DIR="${SCRIPT_DIR}/../env"
NETWORK_NAME="labour-bureau_internal"
POLITBURO_CONTAINER_NAME="politburo"
POLITBURO_IMAGE="politburo:latest"

# Check for --clean flag
CLEAN_BUILD=false
if [[ "$1" == "--clean" ]]; then
    CLEAN_BUILD=true
    echo -e "${YELLOW}⚠️  Clean build requested - will remove old image and build without cache${NC}"
fi

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

# Remove old image if clean build requested
if [[ "$CLEAN_BUILD" == "true" ]]; then
    echo "  Removing old image for clean rebuild..."
    podman rmi "$POLITBURO_IMAGE" 2>/dev/null || true
fi

# Build new image (with --no-cache if clean build)
echo "  Building new image..."
if [[ "$CLEAN_BUILD" == "true" ]]; then
    podman build --no-cache -t "$POLITBURO_IMAGE" -f "${SCRIPT_DIR}/../../../politburo/Dockerfile" "${SCRIPT_DIR}/../../../politburo"
else
    podman build -t "$POLITBURO_IMAGE" -f "${SCRIPT_DIR}/../../../politburo/Dockerfile" "${SCRIPT_DIR}/../../../politburo"
fi

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

# Wait a moment for container to start
sleep 2

# Verify static files are accessible
echo "  Verifying deployment..."
if container_running "$POLITBURO_CONTAINER_NAME"; then
    echo -e "${GREEN}✅ Container is running${NC}"
    
    # Check if static files are accessible
    echo "  Checking static files..."
    if podman exec "$POLITBURO_CONTAINER_NAME" test -f /app/static/js/flight-map.mjs; then
        echo -e "${GREEN}✅ flight-map.mjs found in container${NC}"
    else
        echo -e "${RED}❌ flight-map.mjs NOT found in container${NC}"
    fi
    
    if podman exec "$POLITBURO_CONTAINER_NAME" test -f /app/templates/pages/live.html; then
        echo -e "${GREEN}✅ live.html template found in container${NC}"
    else
        echo -e "${RED}❌ live.html template NOT found in container${NC}"
    fi
else
    echo -e "${RED}❌ Container failed to start${NC}"
    echo "  Checking logs..."
    podman logs --tail 50 "$POLITBURO_CONTAINER_NAME" || true
    exit 1
fi

echo -e "${GREEN}✅ Politburo deployed successfully!${NC}"
echo -e "${YELLOW}💡 Tip: If you see map issues, try:${NC}"
echo -e "   1. Hard refresh browser (Ctrl+Shift+R or Cmd+Shift+R)"
echo -e "   2. Check browser console for JavaScript errors"
echo -e "   3. Verify static files at: http://localhost:8080/static/js/flight-map.mjs"