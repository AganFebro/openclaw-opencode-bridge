#!/bin/bash
# bridge-version: 3
# Keep opencode-daemon tmux session alive (daemon runs every 30s)
# Safe: idempotent, flock-protected (with fallback), short timeout

TMUX="{{TMUX_BIN}}"
OPENCODE="{{OPENCODE_BIN}}"
WORKSPACE="{{WORKSPACE}}"
SESSION="{{SESSION_NAME}}"
LOCK_FILE="/tmp/opencode-session.lock"
TIMEOUT=10

# Use flock for lock protection if available
if command -v flock &> /dev/null; then
    exec 200>"$LOCK_FILE"
    flock -w "$TIMEOUT" 200 || exit 0
else
    # Fallback: simple PID lock (less robust but works without flock)
    if [ -f "$LOCK_FILE" ]; then
        OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            exit 0
        fi
    fi
    echo $$ > "$LOCK_FILE"
fi

# Idempotent: exit if session already exists
if "$TMUX" has-session -t "$SESSION" 2>/dev/null; then
    exit 0
fi

# Create new session + start OpenCode
"$TMUX" new-session -d -s "$SESSION"
"$TMUX" set-option -t "$SESSION" history-limit 10000
"$TMUX" send-keys -t "$SESSION" \
  "cd $WORKSPACE && $OPENCODE --continue" Enter
