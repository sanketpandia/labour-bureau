#!/usr/bin/env bash
#
# start-stage.sh
#
# Starts a tmux session named "infinite-stage" with:
#  - window 0: docker compose up (stage)
#  - window 1: comrade-bot logs
#  - window 2: politburo logs
#  - window 3: vizburo logs
#

SESSION="infinite-stage"
COMPOSE_FILE="docker-compose.dev.yml"

# Set DB connection string for stage
export DATABASE_URL="postgres://ieuser:iepass@db:5432/infinite?sslmode=disable"

# Create tmux session (detached) with window 0 running docker compose up
tmux new-session -d -s "$SESSION" -n "docker-up"
tmux send-keys -t "$SESSION":1 "docker compose -f $COMPOSE_FILE up" C-m

# Window 1 → comrade-bot logs
tmux new-window -t "$SESSION":1 -n "comrade-bot"
tmux send-keys -t "$SESSION":2 "docker compose -f $COMPOSE_FILE logs -f comrade-bot" C-m

# Window 2 → politburo (run directly)
tmux new-window -t "$SESSION":2 -n "politburo"
tmux send-keys -t "$SESSION":3 "cd ../politburo && air -c air.toml" C-m

# Window 3 → vizburo logs
tmux new-window -t "$SESSION":3 -n "vizburo"
tmux send-keys -t "$SESSION":4 "docker compose -f $COMPOSE_FILE logs -f vizburo" C-m

# Back to window 0
tmux select-window -t "$SESSION":0

# Attach
tmux attach-session -t "$SESSION"
