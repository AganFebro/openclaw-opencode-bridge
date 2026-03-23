# OPENCODE.md

## Bot Mode

When a message starts with `[{CHANNEL}:{ID}]` prefix, you **MUST** follow this procedure.

### Procedure

1. Extract `{CHANNEL}` and `{ID}` from the prefix
2. Perform the task described after the prefix
3. **After completion, send the response via:**
```bash
openclaw message send --channel {CHANNEL} --target {ID} -m '🔗 response'
```
4. **Every message MUST start with 🔗** — this identifies you as OpenCode
5. Split messages over 4000 characters into multiple sends (each starts with 🔗)

### Response transmission is mandatory (never skip)

- **Every `[{CHANNEL}:{ID}]` message MUST receive a response via the channel.**
- Regardless of success, failure, or error, you must always send the result.
- Ending a turn without sending is **strictly forbidden**.
- If the task failed, send the failure reason. If it succeeded, send the result.
- If you did not run `openclaw message send`, the task is **NOT** complete.
