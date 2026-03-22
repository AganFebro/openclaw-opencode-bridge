#!/bin/bash
# bridge-version: 1
# Set OpenCode model (accepts number or partial model-id)
TMUX="{{TMUX_BIN}}"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
SELECTION="$1"
USE_SESSION="opencode-models-tmp"
OPENCODE_CONFIG="{{OPENCODE_CONFIG}}"

if [ -z "$SELECTION" ]; then
    echo "❌ Usage: @ccms <number|model-id>"
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "❌ Usage: \`@ccms <number>\` or \`@ccms <model-id>\`\n\nRun \`@ccm\` to see available models." 2>/dev/null
    exit 1
fi

cleanup() {
    "$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
}
trap cleanup EXIT

"$TMUX" kill-session -t "$USE_SESSION" 2>/dev/null
sleep 1
"$TMUX" new-session -d -s "$USE_SESSION"
"$TMUX" set-option -t "$USE_SESSION" history-limit 15000
"$TMUX" send-keys -t "$USE_SESSION" "$OPENCODE models" Enter

sleep 8

PANE=$("$TMUX" capture-pane -t "$USE_SESSION" -p)

FREE_MODELS=""
COUNT=0

while IFS= read -r line; do
    if echo "$line" | grep -qi "free"; then
        COUNT=$((COUNT + 1))
        FREE_MODELS="$FREE_MODELS$COUNT|$line\n"
    fi
done <<< "$PANE"

MODEL_ID=""

if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    MODEL_ID=$(echo -e "$FREE_MODELS" | grep "^$SELECTION|" | cut -d'|' -f2 | xargs)
    SOURCE="number"
else
    MODEL_ID=$(echo -e "$FREE_MODELS" | grep -i "$SELECTION" | head -1 | cut -d'|' -f2 | xargs)
    SOURCE="model-id"
fi

if [ -z "$MODEL_ID" ]; then
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "❌ Model not found.\n\nRun \`@ccm\` to see available FREE models." 2>/dev/null
    exit 1
fi

if [ -f "$OPENCODE_CONFIG" ]; then
    cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.backup" 2>/dev/null
fi

node -e "
const fs = require('fs');
const configPath = '$OPENCODE_CONFIG';
let config = {};

// Read existing config, preserve everything
try {
    if (fs.existsSync(configPath)) {
        const content = fs.readFileSync(configPath, 'utf8');
        try { config = JSON.parse(content); } catch {}
    }
} catch {}

// Ensure schema exists
if (!config['\$schema']) {
    config['\$schema'] = 'https://opencode.ai/config.json';
}

// Only update the model key, keep everything else
config.model = '$MODEL_ID';

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('OK');
"

if [ $? -eq 0 ]; then
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "✅ Model set to \`$MODEL_ID\`\n\nNext \`@cc\`/\`@ccn\` will use this model." 2>/dev/null
    echo "✅ Model set: $MODEL_ID"
else
    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "❌ Failed to set model. Check config path." 2>/dev/null
fi
