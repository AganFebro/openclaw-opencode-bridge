#!/bin/bash
# bridge-version: 3
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

OUTPUT=$("$OPENCODE" run --fork "$FULL_MSG" 2>&1)

openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$OUTPUT"

echo "✅ OpenCode response sent."
