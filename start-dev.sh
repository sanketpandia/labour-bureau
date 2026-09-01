#!/usr/bin/env bash
#
# start-dev.sh — Local dev: backing services via Compose; Politburo and
# comrade-bot on the host for live reload.
#
# Starts a tmux session "infinite-stage" with:
#  - window 1 (compose-up): compose up (db, redis, observability, swagger-editor, …)
#  - window 2 (comrade-bot): npm run dev
#  - window 3 (politburo): Air (optional; prefer VS Code debug instead)
#
# Uses Docker by default. For Podman: CONTAINER_CLI=podman ./start-dev.sh
#

SESSION="infinite-stage"
COMPOSE_FILE="docker-compose.dev.yml"
COMPOSE_CMD="${CONTAINER_CLI:-docker} compose"

tmux new-session -d -s "$SESSION" -n "compose-up"
tmux send-keys -t "$SESSION":1 "$COMPOSE_CMD -f $COMPOSE_FILE up" C-m

tmux new-window -t "$SESSION":2 -n "comrade-bot"
tmux send-keys -t "$SESSION":2 "cd ../comrade-bot && npm run dev" C-m

# Output is tee'd to /tmp/politburo.log so Promtail can scrape it into Loki.
tmux new-window -t "$SESSION":3 -n "politburo"
tmux send-keys -t "$SESSION":3 "cd ../politburo && go tool -modfile=tools/go.mod air -c .air.toml 2>&1 | tee /tmp/politburo.log" C-m

tmux select-window -t "$SESSION":1
tmux attach-session -t "$SESSION"
