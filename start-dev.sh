#!/usr/bin/env bash
#
# start-dev.sh — Local dev: backing services via compose, politburo run on host (e.g. VS Code debug).
#
# Starts a tmux session "infinite-stage" with:
#  - window 0: compose up (db, redis, comrade-bot, vizburo, etc.)
#  - window 1: comrade-bot logs
#  - window 2: politburo via air (optional; prefer "Debug Politburo Server" in VS Code)
#  - window 3: vizburo logs
#
# Uses Docker by default. For Podman: CONTAINER_CLI=podman ./start-dev.sh
#

SESSION="infinite-stage"
COMPOSE_FILE="docker-compose.dev.yml"
# Docker by default; set CONTAINER_CLI=podman to use Podman (same compose file).
COMPOSE_CMD="${CONTAINER_CLI:-docker} compose"

# Set DB connection string for stage
export DATABASE_URL="postgres://ieuser:iepass@db:5432/infinite?sslmode=disable"

# Create tmux session (detached) with window 0 running compose up
tmux new-session -d -s "$SESSION" -n "compose-up"
tmux send-keys -t "$SESSION":0 "$COMPOSE_CMD -f $COMPOSE_FILE up" C-m

# Window 1 → comrade-bot logs
tmux new-window -t "$SESSION":1 -n "comrade-bot"
tmux send-keys -t "$SESSION":1 "$COMPOSE_CMD -f $COMPOSE_FILE logs -f comrade-bot" C-m

# Window 2 → politburo (run directly; optional — can use VS Code "Debug Politburo Server" instead)
tmux new-window -t "$SESSION":2 -n "politburo"
tmux send-keys -t "$SESSION":2 "cd ../politburo && air -c air.toml" C-m

# Window 3 → vizburo logs
tmux new-window -t "$SESSION":3 -n "vizburo"
tmux send-keys -t "$SESSION":3 "$COMPOSE_CMD -f $COMPOSE_FILE logs -f vizburo" C-m

# Back to window 0
tmux select-window -t "$SESSION":0

# Attach
tmux attach-session -t "$SESSION"
