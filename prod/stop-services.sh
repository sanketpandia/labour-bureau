#!/bin/bash
# stop-services.sh - Stop all services

set -e

echo "🛑 Stopping Labour Bureau Services..."

# Stop all containers
podman stop db redis politburo comrade-bot prometheus loki promtail grafana 2>/dev/null || true

echo "✅ All services stopped"
