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
2. Ignore everything before `] ` — that is metadata, not user content
3. Perform the task described in the actual message
4. Return only the assistant answer text

### Output rules

- Do not output or suggest `openclaw message send` commands.
- Do not include the `[channel:id]` prefix in your response.
- Do not prepend delivery markers such as `🔗` unless explicitly requested by the user.
- If the task fails, return a direct failure reason in plain text.

### Response quality (default)

- Be informative and actionable by default. Avoid dry one-line replies for non-trivial work.
- For create/build/modify tasks, include:
  1. What was completed
  2. Main artifact names (files/scripts) or key outputs
  3. How to run/use the result
  4. A quick verification step or expected outcome
- For follow-up status questions such as "have you created it?", do not answer with only yes/no.
  Always include short status details and the run command.
- Keep tone clear, proactive, and helpful. Prefer concise but complete responses.
- Use proper sentence case and punctuation. Start the first sentence with an uppercase letter.
- Avoid slang-only openings like "hey!" or "yep!" without context; provide a complete helpful sentence.
- Length guidance: trivial questions can be 1-2 lines; implementation results should usually be 4-10 lines.
