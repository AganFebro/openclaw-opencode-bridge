#!/bin/bash
# bridge-version: 6
# Start fresh session asynchronously and send instruction
MSG="$1"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
WORKSPACE="{{WORKSPACE}}"
LOG_FILE="/tmp/opencode-bridge-send.log"
BASE_TIMEOUT_SEC=45
MAX_TIMEOUT_SEC=300
LOCK_WAIT_SEC=600

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

acquire_bridge_lock() {
    local safe_channel safe_target lock_file
    safe_channel="$(printf '%s' "$CHANNEL" | sed -E 's/[^a-zA-Z0-9._-]/_/g')"
    safe_target="$(printf '%s' "$TARGET" | sed -E 's/[^a-zA-Z0-9._-]/_/g')"
    lock_file="/tmp/opencode-bridge-${safe_channel}-${safe_target}.lock"

    if command -v flock >/dev/null 2>&1; then
        exec 200>"$lock_file"
        flock -w "$LOCK_WAIT_SEC" 200
        return $?
    fi

    return 0
}

compute_timeout() {
    local msg="$1"
    local timeout="$BASE_TIMEOUT_SEC"
    local chars words

    chars=${#msg}
    words="$(printf '%s' "$msg" | wc -w | tr -d '[:space:]')"

    if [ "$chars" -gt 120 ]; then timeout=$((timeout + 15)); fi
    if [ "$chars" -gt 280 ]; then timeout=$((timeout + 20)); fi
    if [ "$words" -gt 25 ]; then timeout=$((timeout + 20)); fi

    if printf '%s' "$msg" | grep -Eqi '\b(create|build|write|implement|script|code|program|refactor|debug|fix|test|automation|deploy|migrate|api|database|project)\b'; then
        timeout=$((timeout + 60))
    fi

    if printf '%s' "$msg" | grep -Eqi '\b(from scratch|end[- ]to[- ]end|single file|one file|only 1|complex|demanding)\b'; then
        timeout=$((timeout + 30))
    fi

    if [ "$timeout" -gt "$MAX_TIMEOUT_SEC" ]; then
        timeout="$MAX_TIMEOUT_SEC"
    fi

    printf '%s' "$timeout"
}

is_trivial_echo() {
    local output_norm message_norm
    output_norm="$(normalize_text "$1")"
    message_norm="$(normalize_text "$2")"
    [ -n "$message_norm" ] && [ "$output_norm" = "$message_norm" ]
}

extract_last_marked_block() {
    local raw="$1"
    if ! printf '%s' "$raw" | grep -q '🔗'; then
        return 0
    fi

    printf '%s\n' "$raw" | awk '
    {
        pos = index($0, "🔗");
        if (pos > 0) {
            out = substr($0, pos);
            capture = 1;
            next;
        }
        if (capture) {
            out = out "\n" $0;
        }
    }
    END {
        if (capture) print out;
    }'
}

sanitize_output() {
    local raw="$1"
    local cleaned marked

    cleaned="$(printf '%s' "$raw" \
        | tr '\r' '\n' \
        | sed -E $'s/\x1B\\[[0-9;?]*[ -/]*[@-~]//g; s/\x1B\\][^\a]*(\a|\x1B\\\\)//g')"

    cleaned="$(printf '%s\n' "$cleaned" | sed -E 's/\[[0-9]{1,3}m//g')"

    cleaned="$(printf '%s\n' "$cleaned" | grep -Ev \
        '^[[:space:]]*$|^[[:space:]]*(build[[:space:]]*·|◇[[:space:]]+Doctor warnings)[[:space:]]*$|^[[:space:]]*◇[[:space:]]+|^[[:space:]]*[←→↳].*|^[[:space:]]*Wrote file successfully\.?$|^[[:space:]]*(\$[[:space:]]*)?openclaw message send --channel[[:space:]]+|^[[:space:]]*error:[[:space:]]*too many arguments for '\''send'\''.*$|^[[:space:]]*Sent via Telegram|^[[:space:]]*\[(telegram|discord|slack|whatsapp|signal|irc|matrix|line|mattermost|teams)\]|autoSelectFamily=|dnsResultOrder=|^[[:space:]]*[│┌┐└┘├┤┬┴┼─═╭╮╰╯]+[[:space:]]*$')"

    marked="$(extract_last_marked_block "$cleaned")"
    if [ -n "$marked" ]; then
        cleaned="$marked"
    fi

    cleaned="$(printf '%s\n' "$cleaned" | sed -E 's/^🔗[[:space:]]*//')"

    printf '%s' "$(trim_text "$cleaned")"
}

run_with_timeout() {
    local mode="$1"
    local prompt="$2"
    local output rc tmp pid watchdog

    tmp="$(mktemp /tmp/opencode-run.XXXXXX)"
    "$OPENCODE" run "$mode" "$prompt" >"$tmp" 2>&1 &
    pid=$!

    (
        sleep "$RUN_TIMEOUT_SEC"
        if kill -0 "$pid" 2>/dev/null; then
            touch "${tmp}.timeout"
            kill "$pid" 2>/dev/null
            sleep 2
            kill -9 "$pid" 2>/dev/null
        fi
    ) &
    watchdog=$!

    wait "$pid"
    rc=$?
    kill "$watchdog" 2>/dev/null

    if [ -f "${tmp}.timeout" ]; then
        rc=124
        rm -f "${tmp}.timeout"
    fi

    output="$(cat "$tmp")"
    rm -f "$tmp"

    printf '%s\n' "$rc"
    printf '%s' "$output"
}

(
    started_at=$(date +%s)
    RUN_TIMEOUT_SEC="$(compute_timeout "$MSG")"
    cd "$WORKSPACE" || exit 1
    FULL_MSG="[${CHANNEL}:${TARGET}] $MSG"

    if ! acquire_bridge_lock; then
        openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "Bridge is still processing a previous request. Please retry in a moment."
        printf '[%s] /ccn lock timeout after %ss\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOCK_WAIT_SEC"
        exit 0
    fi

    run_result="$(run_with_timeout --fork "$FULL_MSG")"
    rc="$(printf '%s' "$run_result" | head -n 1)"
    output="$(printf '%s' "$run_result" | tail -n +2)"
    output="$(sanitize_output "$output")"

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        output="OpenCode timed out after ${RUN_TIMEOUT_SEC}s. Task may still be running. Try waiting a bit or send a follow-up."
    elif [ -z "$output" ]; then
        output="OpenCode finished, but returned an empty response."
    elif is_trivial_echo "$output" "$MSG"; then
        output="OpenCode ran, but returned a non-informative echo. Please retry with a more specific prompt."
    fi

    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$output"

    ended_at=$(date +%s)
    elapsed=$((ended_at - started_at))
    printf '[%s] /ccn completed in %ss (exit=%s timeout=%ss)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$elapsed" "$rc" "$RUN_TIMEOUT_SEC"
) >>"$LOG_FILE" 2>&1 &

echo "✅ OpenCode new session queued."
