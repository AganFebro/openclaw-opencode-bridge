#!/bin/bash
# bridge-version: 1
# List FREE OpenCode models (filtered from opencode models output)
TMUX="{{TMUX_BIN}}"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
USE_SESSION="opencode-models-tmp"

cleanup() {
    "$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
}
trap cleanup EXIT

"$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
sleep 1
"$TMUX" new-session -d -s "$USE_SESSION"
"$TMUX" set-option -t "$USE_SESSION" history-limit 15000
"$TMUX" send-keys -t "$USE_SESSION" "$OPENCODE models --refresh" Enter

sleep 10

PANE=$("$TMUX" capture-pane -t "$USE_SESSION" -p)

COUNT=0
OUTPUT="🔓 **FREE Models:**\n\n"

while IFS= read -r line; do
    if echo "$line" | grep -qi "free"; then
        COUNT=$((COUNT + 1))
        OUTPUT="$OUTPUT\`[$COUNT]\` $line\n"
    fi
done <<< "$PANE"

if [ "$COUNT" -gt 0 ]; then
    OUTPUT="$OUTPUT\n📝 Usage: \`@ccms <number>\` or \`@ccms <model-id>\`"
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$OUTPUT" 2>/dev/null
    echo "$OUTPUT"
else
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "❌ No FREE models found.\n\nRun \`opencode models --refresh\` to update the list." 2>/dev/null
fi
