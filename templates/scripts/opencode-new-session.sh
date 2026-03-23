#!/bin/bash
# bridge-version: 16
# Start fresh session asynchronously and send instruction
MSG="$1"
OPENCODE="{{OPENCODE_BIN}}"
CHANNEL="{{CHANNEL}}"
TARGET="{{TARGET_ID}}"
WORKSPACE="{{WORKSPACE}}"
LOG_FILE="/tmp/opencode-bridge-send.log"
BASE_TIMEOUT_SEC=90
MAX_TIMEOUT_SEC=420
LOCK_WAIT_SEC=3

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
    local safe_channel safe_target holder_pid waited
    safe_channel="$(printf '%s' "$CHANNEL" | sed -E 's/[^a-zA-Z0-9._-]/_/g')"
    safe_target="$(printf '%s' "$TARGET" | sed -E 's/[^a-zA-Z0-9._-]/_/g')"
    LOCK_DIR="/tmp/opencode-bridge-${safe_channel}-${safe_target}.lockdir"
    waited=0

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        if [ ! -s "$LOCK_DIR/pid" ]; then
            rm -rf "$LOCK_DIR"
            continue
        fi
        if [ -f "$LOCK_DIR/pid" ]; then
            holder_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
            if [ -n "$holder_pid" ] && ! kill -0 "$holder_pid" 2>/dev/null; then
                rm -rf "$LOCK_DIR"
                continue
            fi
        fi

        if [ "$waited" -ge "$LOCK_WAIT_SEC" ]; then
            return 1
        fi
        sleep 1
        waited=$((waited + 1))
    done

    printf '%s\n' "${BASHPID:-$$}" > "$LOCK_DIR/pid"
    trap 'release_bridge_lock' EXIT INT TERM
    return 0
}

release_bridge_lock() {
    if [ -n "${LOCK_DIR:-}" ] && [ -d "$LOCK_DIR" ]; then
        rm -rf "$LOCK_DIR"
    fi
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

    if printf '%s' "$msg" | grep -Eqi '\b(create|build|write|implement|script|code|program|refactor|debug|fix|test|automation|deploy|migrate|api|database|project|search|news|weather|forecast|cuaca|berita)\b'; then
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

    cleaned="$(printf '%s\n' "$cleaned" | sed -E 's/^[[:space:]]*>+[[:space:]]?//; /^```/d')"

    cleaned="$(printf '%s\n' "$cleaned" | grep -Eiv \
        '^[[:space:]]*$|^[[:space:]]*(build[[:space:]]*·|◇[[:space:]]+doctor warnings)[[:space:]]*$|^[[:space:]]*◇[[:space:]]+|^[[:space:]]*exa[[:space:]]+(web|code)[[:space:]]+search([[:space:]]+.*)?$|^[[:space:]]*[←→↳].*|^[[:space:]]*wrote file successfully\.?$|^[[:space:]]*(\$[[:space:]]*)?openclaw message send --channel[[:space:]]+|^[[:space:]]*bridge-guard:[[:space:]]*blocked openclaw message send.*$|^[[:space:]]*error:[[:space:]]*too many arguments for '\''send'\''.*$|^[[:space:]]*sent via telegram|^[[:space:]]*\[(telegram|discord|slack|whatsapp|signal|irc|matrix|line|mattermost|teams)\]|autoselectfamily=|dnsresultorder=|^[[:space:]]*[│┌┐└┘├┤┬┴┼─═╭╮╰╯]+[[:space:]]*$')"

    marked="$(extract_last_marked_block "$cleaned")"
    if [ -n "$marked" ]; then
        cleaned="$marked"
    fi

    cleaned="$(printf '%s\n' "$cleaned" | sed -E 's/^🔗[[:space:]]*//')"

    printf '%s' "$(trim_text "$cleaned")"
}

extract_text_from_json_stream() {
    local raw="$1"
    local parsed

    parsed="$(printf '%s\n' "$raw" | node -e "const fs=require('fs');const lines=fs.readFileSync(0,'utf8').split(/\r?\n/);let out='';for(const line of lines){const s=line.trim();if(!s)continue;try{const obj=JSON.parse(s);if(obj&&obj.type==='text'&&obj.part&&typeof obj.part.text==='string'){out+=obj.part.text;}}catch{}}process.stdout.write(out);" 2>/dev/null)"
    printf '%s' "$(trim_text "$parsed")"
}

sentence_case_first() {
    local text="$1"
    printf '%s' "$text" | awk '
    BEGIN { done = 0 }
    {
        if (done) { print; next }
        line = $0
        for (i = 1; i <= length(line); i++) {
            ch = substr(line, i, 1)
            if (ch ~ /[a-z]/) {
                pre = substr(line, 1, i - 1)
                post = substr(line, i + 1)
                line = pre toupper(ch) post
                done = 1
                break
            } else if (ch ~ /[A-Z]/) {
                done = 1
                break
            }
        }
        print line
    }'
}

apply_reply_style() {
    local text="$1"
    text="$(trim_text "$text")"
    [ -z "$text" ] && { printf '%s' "$text"; return; }
    text="$(sentence_case_first "$text")"
    printf '%s' "$text"
}

run_with_timeout() {
    local mode="$1"
    local prompt="$2"
    local output rc tmp pid watchdog guard_dir guarded_path real_openclaw

    tmp="$(mktemp /tmp/opencode-run.XXXXXX)"
    guarded_path="$PATH"
    real_openclaw="$(command -v openclaw 2>/dev/null || true)"
    if [ -n "$real_openclaw" ]; then
        guard_dir="$(mktemp -d /tmp/opencode-bridge-guard.XXXXXX)"
        printf '#!/bin/sh\nif [ "$1" = "message" ] && [ "$2" = "send" ]; then\n  echo "bridge-guard: blocked openclaw message send from opencode runtime" >&2\n  exit 64\nfi\nexec "%s" "$@"\n' "$real_openclaw" > "${guard_dir}/openclaw"
        chmod +x "${guard_dir}/openclaw"
        guarded_path="${guard_dir}:${PATH}"
    fi

    # Timeout here is an upper bound only; command returns immediately when OpenCode finishes.
    if command -v timeout >/dev/null 2>&1; then
        if [ -n "$mode" ]; then
            PATH="$guarded_path" timeout --signal=TERM --kill-after=2 "${RUN_TIMEOUT_SEC}s" \
                "$OPENCODE" run "$mode" --no-fork --format json "$prompt" >"$tmp" 2>&1
        else
            PATH="$guarded_path" timeout --signal=TERM --kill-after=2 "${RUN_TIMEOUT_SEC}s" \
                "$OPENCODE" run --no-fork --format json "$prompt" >"$tmp" 2>&1
        fi
        rc=$?
    else
        if [ -n "$mode" ]; then
            PATH="$guarded_path" "$OPENCODE" run "$mode" --no-fork --format json "$prompt" >"$tmp" 2>&1 &
        else
            PATH="$guarded_path" "$OPENCODE" run --no-fork --format json "$prompt" >"$tmp" 2>&1 &
        fi
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
    fi

    output="$(cat "$tmp")"
    rm -f "$tmp"
    [ -n "${guard_dir:-}" ] && rm -rf "$guard_dir"

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

    # Fresh request: run without --continue to avoid session carryover.
    run_result="$(run_with_timeout "" "$FULL_MSG")"
    rc="$(printf '%s' "$run_result" | head -n 1)"
    raw_output="$(printf '%s' "$run_result" | tail -n +2)"
    output="$(extract_text_from_json_stream "$raw_output")"
    if [ -z "$output" ]; then
        output="$(sanitize_output "$raw_output")"
    fi

    if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
        if [ -n "$output" ] && ! is_trivial_echo "$output" "$MSG"; then
            output="${output}\n\n(Stopped after ${RUN_TIMEOUT_SEC}s timeout.)"
        else
            output="OpenCode timed out after ${RUN_TIMEOUT_SEC}s. Try a narrower prompt or send a follow-up."
        fi
    elif [ -z "$output" ]; then
        output="OpenCode finished, but returned an empty response."
    elif is_trivial_echo "$output" "$MSG"; then
        output="OpenCode ran, but returned a non-informative echo. Please retry with a more specific prompt."
    fi

    output="$(apply_reply_style "$output")"

    openclaw message send --channel "$CHANNEL" --target "$TARGET" -m "$output"

    ended_at=$(date +%s)
    elapsed=$((ended_at - started_at))
    printf '[%s] /ccn completed in %ss (exit=%s timeout=%ss)\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$elapsed" "$rc" "$RUN_TIMEOUT_SEC"
) >>"$LOG_FILE" 2>&1 &

echo "✅ OpenCode new session queued."
