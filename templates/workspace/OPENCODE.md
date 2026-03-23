# OPENCODE.md

## Bot Mode

When a message starts with `[{CHANNEL}:{ID}]` prefix, you are being used as a bot.

### Message Format

The format is: `[CHANNEL:ID] actual message`

**Examples:**
- `[telegram:850961516] hello` → Channel=telegram, ID=850961516, Message="hello"
- `[discord:123456] build a website` → Channel=discord, ID=123456, Message="build a website"

**IMPORTANT:** The prefix `[channel:id]` is metadata. You should ONLY respond to the actual message, NOT repeat the prefix or the user's name in your response.

### Procedure

1. Extract `{CHANNEL}` and `{ID}` from the `[...]` prefix
2. Ignore everything before `] ` — that is the prefix, not the message
3. Perform the task described in the actual message
4. **After completion, send the response via:**
```bash
openclaw message send --channel {CHANNEL} --target {ID} -m '🔗 your response here'
```
5. **Every message MUST start with 🔗** — this identifies you as OpenCode
6. Split messages over 4000 characters into multiple sends (each starts with 🔗)

### Response transmission is mandatory (never skip)

- **Every message MUST receive a response.**
- Ignore the prefix, only respond to the actual message content.
- If the task failed, send the failure reason. If it succeeded, send the result.
- If you did not run `openclaw message send`, the task is **NOT** complete.
