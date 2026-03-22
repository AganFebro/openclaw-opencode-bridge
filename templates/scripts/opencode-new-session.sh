#!/bin/bash
# bridge-version: 1
# Kill existing session -> create new session -> send instruction
MSG="$1"
TMUX="{{TMUX_BIN}}"
OPENCODE="{{OPENCODE_BIN}}"
WORKSPACE="{{WORKSPACE}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
SESSION="{{SESSION_NAME}}"

if [ -z "$MSG" ]; then
    echo "ERROR: No message provided"
    exit 1
fi

# Kill existing session
if "$TMUX" has-session -t "$SESSION" 2>/dev/null; then
    "$TMUX" kill-session -t "$SESSION" 2>/dev/null
    sleep 1
fi

# Create new session
"$TMUX" new-session -d -s "$SESSION"
"$TMUX" set-option -t "$SESSION" history-limit 10000
"$TMUX" send-keys -t "$SESSION" "cd $WORKSPACE && $OPENCODE" Enter

# Wait for OpenCode prompt
WAIT=0
while [ $WAIT -lt 60 ]; do
    PANE=$("$TMUX" capture-pane -t "$SESSION" -p)
    if echo "$PANE" | grep -qE "❯|>|opencode"; then
        break
    fi
    sleep 2
    WAIT=$((WAIT + 2))
done

# Send instruction
sleep 1
printf '%s' "[${CHANNEL}:${TARGET}] $MSG" | "$TMUX" load-buffer -
"$TMUX" paste-buffer -t "$SESSION" -d -p
sleep 0.3
"$TMUX" send-keys -t "$SESSION" Enter

echo "✅ New session started. Reply will arrive shortly."
