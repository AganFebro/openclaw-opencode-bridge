#!/bin/bash
# bridge-version: 3
# Send instruction to OpenCode and relay response to telegram
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

OUTPUT=$("$OPENCODE" run --continue "$FULL_MSG" 2>&1)

openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$OUTPUT"

echo "✅ OpenCode response sent."
