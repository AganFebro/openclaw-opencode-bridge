# openclaw-opencode-bridge

[![npm version](https://img.shields.io/npm/v/openclaw-opencode-bridge)](https://www.npmjs.com/package/openclaw-opencode-bridge)
[![license](https://img.shields.io/npm/l/openclaw-opencode-bridge)](LICENSE)
[![node](https://img.shields.io/node/v/openclaw-opencode-bridge)](package.json)

Bridge OpenClaw channels to OpenCode using command prefixes like `/cc` or `@cc`.

User messages are executed via OpenCode CLI (`opencode run`), then sent back through `openclaw message send`.

Language: [Bahasa Indonesia](README.md)

<p>
  <img src="DEMO_1.png" alt="Telegram demo — sending a command" width="400" />
  <img src="DEMO_2.png" alt="Telegram demo — receiving a response" width="400" />
</p>

> ⚠️ Current testing focus is Telegram. Other channels may need format-specific adjustments.

## Key Features

- Prefix commands: `@cc`, `/cc`, `@ccn`, `/ccn`, `@ccu`, `@ccm`, `@ccms`
- OpenCode output is automatically sent back to users via OpenClaw
- Output is sanitized to remove terminal/tool noise
- Timeout acts as a maximum limit, not a fixed delay
- Automatic onboarding and uninstall workflow

## How It Works

1. User sends a prefixed message, for example: `/cc build a python script`.
2. The plugin intercepts the message and suppresses the default gateway reply.
3. Bridge scripts run `opencode run`.
4. OpenCode output is delivered back to the same user/channel.

## Prerequisites

| Dependency | Install |
|---|---|
| [OpenClaw](https://openclaw.ai) | `npm i -g openclaw` |
| [OpenCode](https://opencode.ai) | `npm i -g opencode-ai` |
| [tmux](https://github.com/tmux/tmux) | Auto-installed during onboard if missing |

> Supported OS: Linux and macOS.

## Quick Start

```bash
npm i -g openclaw-opencode-bridge
openclaw-opencode-bridge onboard
```

Onboarding configures plugin entries, scripts, AGENTS.md, daemon, and channel settings.

Quick test:

```bash
/cc hello
```

## Command List

| Prefix | Function |
|---|---|
| `@cc` · `/cc` | Continue the latest session (`--continue`) |
| `@ccn` · `/ccn` | Start a fresh run without `--continue` |
| `@ccu` · `/ccu` | Show OpenCode usage stats |
| `@ccm` · `/ccm` | List OpenCode models |
| `@ccms` · `/ccms` | Set OpenCode model (number or model-id) |

Examples:

```bash
/cc refactor auth module and add tests
/ccn review this PR: https://github.com/org/repo/pull/42
/ccu
```

## Timeout Behavior

- `/cc` uses adaptive timeout with base `300s` and max `600s`.
- `/ccn` uses adaptive timeout with base `300s` and max `600s`.
- Timeout is a hard upper bound. If OpenCode finishes early, output is sent immediately.

## Session Notes

- `/ccn` does not delete existing OpenCode history.
- `/cc` usually continues the latest session.
- OpenCode session data is stored in OpenCode user data directory (Linux example: `~/.local/share/opencode`).

## Migration from Legacy Version

Version 2+ replaces the legacy skill/hook flow with a single OpenClaw plugin:

```bash
npm i -g openclaw-opencode-bridge
openclaw-opencode-bridge onboard
```

Legacy components are cleaned automatically during onboarding.

## Uninstall

```bash
openclaw-opencode-bridge uninstall
```

This removes plugin entries, bridge scripts, bridge-managed AGENTS.md, and daemon registration.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Gateway LLM still responds | Run `openclaw gateway restart` |
| Delivery message appears but no final reply | Check `/tmp/opencode-bridge-send.log`, then rerun `openclaw-opencode-bridge onboard` |
| Slow response / timeout | Check prompt complexity and bridge logs; confirm OpenCode CLI is healthy |
| Messy output | Rerun onboarding to ensure latest scripts/plugin are installed |

## Donation

If this project helps you, you can support it via:

`0xe81c32383C8F21A14E6C2264939dA512e9F9bb42`

## Attribution

This project is adapted from the original work:
`https://github.com/bettep-dev/openclaw-claude-bridge`

## License

[MIT](LICENSE)
