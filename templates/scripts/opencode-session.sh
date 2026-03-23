#!/bin/bash
# bridge-version: 4
# Keep OpenCode server alive (runs every 30s via daemon)
# Safe: idempotent, flock-protected (with fallback)

OPENCODE="{{OPENCODE_BIN}}"
WORKSPACE="{{WORKSPACE}}"
LOCK_FILE="/tmp/opencode-session.lock"
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

# Start OpenCode in server mode if not running
if ! pgrep -f "opencode serve" > /dev/null 2>&1; then
    "$OPENCODE" serve &
    sleep 2
fi

exit 0
