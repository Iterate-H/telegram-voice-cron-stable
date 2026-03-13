# telegram-voice-cron-stable

English | [中文](./README.zh-CN.md)

An [OpenClaw](https://github.com/openclaw/openclaw) skill that stabilizes scheduled Telegram text + voice delivery for cron jobs.

## Problem

OpenClaw's cron announce pipeline has known silent-failure bugs when delivering to Telegram ([#14743](https://github.com/openclaw/openclaw/issues/14743), [#25670](https://github.com/openclaw/openclaw/issues/25670), [#31714](https://github.com/openclaw/openclaw/issues/31714)):

- Messages sent via `delivery.mode=announce` never reach Telegram (no error logged)
- Internal relay text leaks into user-visible messages
- `deliveryStatus` falsely reports `delivered` while nothing was actually sent

## Solution

This skill provides a deterministic delivery template that bypasses the unreliable announce relay:

1. **`delivery.mode=none`** — disables Gateway announce relay entirely
2. **Explicit send steps** — agent sends text and voice (`asVoice=true`) directly via tool calls
3. **TTS fallback chain** — automatic retry with chunking, then degraded short voice on failure

> **Update (v2026.3.11+):** The announce pipeline fix ([PR #31810](https://github.com/openclaw/openclaw/issues/31714)) landed in v2026.3.11. If you're on v2026.3.12+, you can use `delivery.mode=announce` for text delivery and let the agent handle voice only. See [Usage](#usage) for both modes.

## Quick Start

```bash
# Clone
git clone https://github.com/Iterate-H/telegram-voice-cron-stable.git

# Apply to a cron job
bash scripts/apply-stable-cron.sh \
  --job-id <cronJobId> \
  --target <telegramChatId> \
  --prompt-file /path/to/your-prompt.md \
  --voice zh-CN-XiaoxiaoNeural

# Test
openclaw cron run <cronJobId>

# Verify
openclaw cron runs --id <cronJobId> --limit 1
```

## Usage

### Mode A: Agent sends everything (pre-v2026.3.11 or maximum control)

The apply script sets `delivery.mode=none` and injects a message template where the agent:

1. Sends text to Telegram via tool call
2. Generates TTS audio with Edge TTS
3. Sends voice bubble (`asVoice=true`) to Telegram
4. Outputs `NO_REPLY`

### Mode B: Announce + agent voice (v2026.3.12+, recommended)

After upgrading OpenClaw, switch to announce for text delivery:

```bash
openclaw cron edit <jobId> \
  --announce \
  --channel telegram \
  --to <chatId> \
  --best-effort-deliver
```

Then update the agent message so it only sends the voice bubble and outputs the full report text as its final response (announce delivers the text automatically).

## TTS Failure Handling

The template enforces a strict fallback chain:

| Step | Condition | Action |
|------|-----------|--------|
| 1 | TTS succeeds | Send voice bubble normally |
| 2 | First failure | Retry with chunked text (<=800 chars per segment) |
| 3 | Second failure | Send failure notice text to same chat |
| 4 | Degraded voice | Send short voice (title + 3 action items) within 60s |

Voice delivery is never silently skipped — every code path produces at least one voice bubble.

## File Structure

```
telegram-voice-cron-stable/
  SKILL.md           # OpenClaw skill definition (frontmatter + instructions)
  skill-info.json    # Skill metadata for packaging/distribution
  scripts/
    apply-stable-cron.sh   # One-command setup script
  dist/
    telegram-voice-cron-stable.skill   # Packaged skill (zip)
```

## Requirements

- [OpenClaw](https://github.com/openclaw/openclaw) (CLI: `openclaw cron edit`, `openclaw cron run`)
- [Edge TTS](https://github.com/nicekid1/node-edge-tts) (via node-edge-tts, internet required)
- Telegram bot with send permissions to the target chat

## License

MIT
