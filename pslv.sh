#!/usr/bin/env bash

SESSION="infinite-dev"

tmux has-session -t "$SESSION" 2>/dev/null
if [[ $? -ne 0 ]]; then
    tmux new-session -d -s "$SESSION" -n "window0"

    tmux new-window -t "$SESSION":1 -n "comrade-bot"
    tmux send-keys -t "$SESSION":1 "cd \$HOME/projects/infinite-experiment/comrade-bot && sh run-script.sh" C-m

    tmux new-window -t "$SESSION":2 -n "politburo"
    tmux send-keys -t "$SESSION":2 "cd \$HOME/projects/infinite-experiment/politburo && sh run-script.sh" C-m

    tmux new-window -t "$SESSION":3 -n "vizburo"
    tmux send-keys -t "$SESSION":3 "cd \$HOME/projects/infinite-experiment/labour-bureau && sh vizburo-script.sh" C-m
fi

tmux attach -t "$SESSION"

