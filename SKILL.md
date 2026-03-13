---
name: telegram-voice-cron-stable
version: "1.0.0"
description: |
  Stabilize scheduled Telegram text+voice delivery for OpenClaw cron jobs.
  Use when: (1) Cron job must reliably send text + voice bubble to Telegram.
  (2) Built-in announce delivery fails silently. (3) Need TTS fallback on failure.
metadata:
  {
    "openclaw":
      {
        "emoji": "📢",
        "requires": { "bins": ["openclaw"] },
      },
  }
---

# Telegram Voice Cron Stable

## Overview

OpenClaw cron announce delivery has known silent-failure bugs when targeting Telegram (Issue #14743, #25670). The Gateway announce relay may drop messages entirely or leak internal relay text into user-visible messages. This skill bypasses the problem in three steps:

1. Set cron delivery mode to `none` to disable Gateway announce relay
2. Embed deterministic send steps directly in the agent message (text first, then voice)
3. Enforce TTS fallback chain: retry with chunking, then failure notice + degraded short voice

## When to trigger

Apply this skill when any of the following conditions are met:

- Cron job needs to send both **text + voice bubble** to Telegram
- Announce delivery results in no Telegram response (silent failure)
- User reports receiving internal relay text instead of expected content
- TTS failure fallback is required

## Do this

1. Set cron delivery mode to `none` so Gateway announce relay does not interfere with tool sends.
2. Put deterministic send rules in the cron `agentTurn.message`:
   - Send text first
   - Send voice second with `asVoice=true`
   - Sanitize spoken text (remove code blocks/backticks/shell operators/long URLs)
   - Retry TTS once with chunking
   - If still failing, send failure note + degraded short voice within 60s
   - End with `NO_REPLY`
3. Test immediately with `openclaw cron run <jobId>`.
4. Inspect result with `openclaw cron runs --id <jobId> --limit 1`.

## Apply helper script

Run:

```bash
bash skills/telegram-voice-cron-stable/scripts/apply-stable-cron.sh \
  --job-id <cronJobId> \
  --target <telegramChatId> \
  --prompt-file <absolute-prompt-path> \
  --voice zh-CN-XiaoxiaoNeural
```

Script effect:

- Updates cron message with stable template
- Forces `delivery.mode=none`
- Keeps the same schedule and timeout
- Prints final cron config for confirmation

## Failure handling

TTS failure fallback follows a strict chain:

1. **First failure** — auto-retry with chunked text (each chunk <= 800 chars)
2. **Second failure** — immediately send a failure notice text to the same Telegram chat
3. **Degraded voice** — within 60s, send a short voice (title + 3 action items only), still using `asVoice=true`
4. **No silent skip** — every code path must produce at least one voice bubble

## Verify checklist

- `delivery.mode` is `none`
- Telegram receives text
- Telegram receives voice bubble (not generic audio file)
- No internal relay text appears in user-visible messages
- On TTS error, user receives explicit failure notice + degraded voice

## Troubleshooting

| Symptom | What to check |
|---------|---------------|
| Telegram receives nothing | Check `openclaw cron runs` logs; verify job executed; verify target chat ID |
| Text received but no voice | Check Edge TTS service reachability; confirm `asVoice=true` in send params |
| Voice arrives as file, not bubble | Confirm using `asVoice=true` instead of plain media send |
| Internal relay text visible | `delivery.mode` not set to `none`; re-run apply script |
| Apply script errors | Confirm `openclaw` CLI is installed and in PATH; check prompt file is absolute path |

## Notes

- Requires `openclaw` CLI (`openclaw cron edit`, `openclaw cron run`)
- Requires Edge TTS service (via node-edge-tts), internet connection needed
- Default voice: `zh-CN-XiaoxiaoNeural`, changeable via `--voice` flag
- This skill only replaces the message template and delivery mode; schedule and timeout are preserved
- Known limitation: if Telegram Bot Token expires or chat permissions change, the send step itself will fail — this is outside the scope of this skill
