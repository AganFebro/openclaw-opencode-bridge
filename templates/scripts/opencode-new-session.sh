#!/bin/bash
# bridge-version: 2
# Start fresh session and send instruction
MSG="$1"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
WORKSPACE="{{WORKSPACE}}"

if [ -z "$MSG" ]; then
    echo "ERROR: No message provided"
    exit 1
fi

cd "$WORKSPACE"
FULL_MSG="[${CHANNEL}:${TARGET}] $MSG"

"$OPENCODE" run --fork "$FULL_MSG" 2>&1 &

echo "✅ New session started. Reply will arrive shortly."
