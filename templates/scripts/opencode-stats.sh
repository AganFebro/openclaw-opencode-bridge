#!/bin/bash
# bridge-version: 1
# Query OpenCode usage/stats info, send result via channel
TMUX="{{TMUX_BIN}}"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
WORKSPACE="{{WORKSPACE}}"
USE_SESSION="opencode-stats-tmp"

cleanup() {
    "$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
}
trap cleanup EXIT

"$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
sleep 1
"$TMUX" new-session -d -s "$USE_SESSION"
"$TMUX" set-option -t "$USE_SESSION" history-limit 5000
"$TMUX" send-keys -t "$USE_SESSION" "cd $WORKSPACE && $OPENCODE stats --project ''" Enter

sleep 8

PANE=$("$TMUX" capture-pane -t "$USE_SESSION" -p)

openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$PANE" 2>/dev/null
echo "$PANE"
