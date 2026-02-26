#!/bin/bash
# stop-services.sh - Stop all services

set -e

echo "🛑 Stopping Labour Bureau Services..."

# Stop all containers
podman stop labour-bureau_db_1 redis-prod labour-bureau_politburo_1 labour-bureau_comrade-bot_1 prometheus loki promtail grafana 2>/dev/null || true

echo "✅ All services stopped"
