#!/bin/bash
# bridge-version: 2
# Send instruction to OpenCode (non-interactive mode)
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

"$OPENCODE" run --continue "$FULL_MSG" 2>&1 &

echo "✅ Delivered to OpenCode. Reply will arrive shortly."
