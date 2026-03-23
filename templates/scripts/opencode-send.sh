#!/bin/bash
# bridge-version: 4
# Dispatch instruction to OpenCode asynchronously and relay response
MSG="$1"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
WORKSPACE="{{WORKSPACE}}"
RUN_TIMEOUT_SEC=45
LOG_FILE="/tmp/opencode-bridge-send.log"

if [ -z "$MSG" ]; then
    echo "ERROR: No message provided"
    exit 1
fi

trim_text() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

normalize_text() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/^🔗[[:space:]]*//; s/^["'\''`]+|["'\''`]+$//g; s/[[:space:]]+/ /g; s/^[[:space:]]+|[[:space:]]+$//g'
}

is_trivial_echo() {
    local output_norm message_norm
    output_norm="$(normalize_text "$1")"
    message_norm="$(normalize_text "$2")"
    [ -n "$message_norm" ] && [ "$output_norm" = "$message_norm" ]
}

run_with_timeout() {
    local mode="$1"
    local prompt="$2"
    local output rc

    if command -v timeout >/dev/null 2>&1; then
        output=$(timeout "${RUN_TIMEOUT_SEC}s" "$OPENCODE" run "$mode" "$prompt" 2>&1)
        rc=$?
    elif command -v gtimeout >/dev/null 2>&1; then
        output=$(gtimeout "${RUN_TIMEOUT_SEC}s" "$OPENCODE" run "$mode" "$prompt" 2>&1)
        rc=$?
    else
        output=$("$OPENCODE" run "$mode" "$prompt" 2>&1)
        rc=$?
    fi

    printf '%s\n' "$rc"
    printf '%s' "$output"
}

(
    started_at=$(date +%s)
    cd "$WORKSPACE" || exit 1
    FULL_MSG="[${CHANNEL}:${TARGET}] $MSG"

    run_result="$(run_with_timeout --continue "$FULL_MSG")"
    rc="$(printf '%s' "$run_result" | head -n 1)"
    output="$(printf '%s' "$run_result" | tail -n +2)"

    output="$(printf '%s\n' "$output" | sed -E '/^[[:space:]]*openclaw message send --channel[[:space:]]+/d')"
    output="$(trim_text "$output")"

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        output="OpenCode timed out after ${RUN_TIMEOUT_SEC}s. Please retry with a narrower request."
    elif [ -z "$output" ]; then
        output="OpenCode finished, but returned an empty response."
    elif is_trivial_echo "$output" "$MSG"; then
        output="OpenCode ran, but returned a non-informative echo. Please retry with a more specific prompt."
    fi

    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$output"

    ended_at=$(date +%s)
    elapsed=$((ended_at - started_at))
    printf '[%s] /cc completed in %ss (exit=%s)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$elapsed" "$rc"
) >>"$LOG_FILE" 2>&1 &

echo "✅ OpenCode request queued."
