#!/bin/bash
# bridge-version: 5
# Keep OpenCode server running in background (for faster message processing)
# Daemon runs every 30s to ensure server stays alive

OPENCODE="{{OPENCODE_BIN}}"
WORKSPACE="{{WORKSPACE}}"
LOCK_FILE="/tmp/opencode-session.lock"
PID_FILE="/tmp/opencode-session.pid"
TIMEOUT=10

# Use flock for lock protection if available
if command -v flock &> /dev/null; then
    exec 200>"$LOCK_FILE"
    flock -w "$TIMEOUT" 200 || exit 0
else
    # Fallback: simple PID lock
    if [ -f "$LOCK_FILE" ]; then
        OLD_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
            exit 0
        fi
    fi
    echo $$ > "$LOCK_FILE"
fi

cd "$WORKSPACE"

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        exit 0
    fi
fi

# Start OpenCode server in background
nohup "$OPENCODE" serve > /tmp/opencode-serve.log 2>&1 &
echo $! > "$PID_FILE"
sleep 3

exit 0
