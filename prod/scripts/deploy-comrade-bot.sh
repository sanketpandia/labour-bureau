#!/bin/bash
# deploy-comrade-bot.sh - Deploy Comrade Bot service (stop, rebuild, restart)
# Usage: ./deploy-comrade-bot.sh [local|global]
#   local  - Deploy commands to guild (requires GUILD_ID in env)
#   global - Deploy commands globally (default if no argument)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

ENV_DIR="${SCRIPT_DIR}/../env"
NETWORK_NAME="labour-bureau_internal"
COMRADE_BOT_CONTAINER_NAME="comrade-bot"
COMRADE_BOT_IMAGE="comrade-bot:latest"

# Get deployment mode from argument (default to global)
DEPLOY_MODE="${1:-global}"

echo -e "${GREEN}🚀 Deploying Comrade Bot...${NC}"

# Stop container if running
if container_running "$COMRADE_BOT_CONTAINER_NAME"; then
    echo "  Stopping container..."
    podman stop "$COMRADE_BOT_CONTAINER_NAME"
fi

# Remove container if it exists
if container_exists "$COMRADE_BOT_CONTAINER_NAME"; then
    echo "  Removing container..."
    podman rm "$COMRADE_BOT_CONTAINER_NAME"
fi

# Optionally remove old image (uncomment to force clean rebuild)
# echo "  Removing old image..."
# podman rmi "$COMRADE_BOT_IMAGE" 2>/dev/null || true

# Build new image
echo "  Building new image..."
podman build -t "$COMRADE_BOT_IMAGE" -f "${SCRIPT_DIR}/../../../comrade-bot/Dockerfile" "${SCRIPT_DIR}/../../../comrade-bot"

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

# Create and start new container
echo "  Creating and starting container..."
podman run -d \
    --name "$COMRADE_BOT_CONTAINER_NAME" \
    --network "$NETWORK_NAME" \
    --env-file "${ENV_DIR}/comrade-bot.env" \
    -e DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN}" \
    --restart unless-stopped \
    "$COMRADE_BOT_IMAGE"

# Wait for container to be ready
echo "  Waiting for container to be ready..."
sleep 3

# Deploy Discord commands
echo "  Deploying Discord commands (mode: $DEPLOY_MODE)..."
if [ "$DEPLOY_MODE" = "local" ]; then
    podman exec "$COMRADE_BOT_CONTAINER_NAME" npm run deploy:local || {
        echo -e "  ${YELLOW}⚠ Warning: Command deployment failed. You can deploy manually later with:${NC}"
        echo -e "  ${YELLOW}   podman exec $COMRADE_BOT_CONTAINER_NAME npm run deploy:local${NC}"
    }
else
    podman exec "$COMRADE_BOT_CONTAINER_NAME" npm run deploy:global || {
        echo -e "  ${YELLOW}⚠ Warning: Command deployment failed. You can deploy manually later with:${NC}"
        echo -e "  ${YELLOW}   podman exec $COMRADE_BOT_CONTAINER_NAME npm run deploy:global${NC}"
    }
fi

echo -e "${GREEN}✅ Comrade Bot deployed successfully!${NC}"
