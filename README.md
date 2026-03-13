# AI Daily Intelligence Report

English | [中文](./README.zh-CN.md)

A fully automated AI news curation pipeline: scans global AI developments daily, filters out hype, and delivers a structured text + voice report to Telegram every morning.

Built on [OpenClaw](https://github.com/openclaw/openclaw) + [Edge TTS](https://github.com/nicekid1/node-edge-tts).

## What You Get

Every day at 08:30, a structured report lands in your Telegram — both as readable text and a voice bubble you can listen to while commuting:

- **S-tier picks** (0–2): verified breakthroughs or immediately useful tools, with action steps
- **Toolbox updates** (3–6): practical tools/repos, each with use-case scenario and trust rating
- **Noise filter**: what to ignore today and why
- **3 action items**: concrete next steps you can execute today

## Anti-Hype Philosophy

The prompt enforces strict filtering:

- **Pass**: foundational model updates (A-tier), immediately usable tools/plugins/open-source projects (B-tier)
- **Drop**: opinion pieces, "PPT products" with no demo/code, stock news, marketing clickbait
- **Source trust rating**: every item tagged S/A/B/C based on origin (official repo > active open-source > aggregator > personal repost)
- **Verification required**: S-tier items must have fetchable evidence from official sources, or get downgraded

## How It Works

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│  Cron 08:30 │────▶│ Agent scans  │────▶│ Filter/rank  │────▶│ Telegram │
│  (OpenClaw) │     │ sources      │     │ anti-hype    │     │ text +   │
│             │     │ (web_search  │     │ S/B/C/D tier │     │ voice 🔊 │
│             │     │  + web_fetch)│     │              │     │          │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
```

1. **OpenClaw cron** triggers an isolated agent session daily
2. **Agent** executes the [prompt](./prompts/ai-intel-daily-prompt.md): searches 5 source categories, cross-validates via official URLs
3. **Report** generated in structured format with actionable insights
4. **Delivery**: text via announce, voice via Edge TTS (`asVoice=true`)
5. **TTS fallback**: retry with chunking → failure notice → degraded short voice (never silent)

## Quick Start

### 1. Create a cron job in OpenClaw

```bash
openclaw cron add \
  --name "ai-intel:daily-0830" \
  --cron "30 8 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --announce \
  --channel telegram \
  --to <your-telegram-chat-id> \
  --best-effort-deliver \
  --timeout-seconds 900
```

### 2. Apply the stable delivery template

```bash
bash scripts/apply-stable-cron.sh \
  --job-id <cronJobId> \
  --target <your-telegram-chat-id> \
  --prompt-file /absolute/path/to/prompts/ai-intel-daily-prompt.md \
  --voice zh-CN-XiaoxiaoNeural
```

### 3. Test

```bash
openclaw cron run <cronJobId>
openclaw cron runs --id <cronJobId> --limit 1
```

Check Telegram for text message + round voice bubble.

## Customization

### Change the prompt

Edit [`prompts/ai-intel-daily-prompt.md`](./prompts/ai-intel-daily-prompt.md) to adjust:

- **Sources**: add/remove from the whitelist (GitHub, HuggingFace, official blogs, etc.)
- **Filter criteria**: what counts as S-tier vs noise for your domain
- **Output format**: restructure sections to match your reading style
- **Language**: the prompt is in Chinese but works with any language — just rewrite the output format

### Change the voice

```bash
# List available voices
node node_modules/node-edge-tts/examples/list-voices.js

# Common choices
--voice zh-CN-XiaoxiaoNeural    # Chinese female (default)
--voice zh-CN-YunxiNeural       # Chinese male
--voice en-US-AriaNeural        # English female
```

### Change the schedule

```bash
openclaw cron edit <jobId> --cron "0 9 * * *"   # 09:00 daily
openclaw cron edit <jobId> --cron "0 9 * * 1-5"  # Weekdays only
```

## Delivery Stability

This project includes a workaround for known OpenClaw announce delivery bugs ([#14743](https://github.com/openclaw/openclaw/issues/14743), [#25670](https://github.com/openclaw/openclaw/issues/25670), [#31714](https://github.com/openclaw/openclaw/issues/31714)) that cause silent message loss to Telegram.

**If on OpenClaw v2026.3.12+** (recommended): use `--announce` mode. The fix is included.

**If on older versions**: the apply script sets `delivery.mode=none` and the agent sends both text and voice directly via tool calls, bypassing the broken announce pipeline.

### TTS Fallback Chain

| Step | Condition | Action |
|------|-----------|--------|
| 1 | TTS succeeds | Send voice bubble normally |
| 2 | First failure | Retry with chunked text (<=800 chars/segment) |
| 3 | Second failure | Send failure notice to chat |
| 4 | Degraded voice | Short voice (title + 3 items) within 60s |

Every code path produces at least one voice bubble — delivery never silently fails.

## File Structure

```
├── README.md
├── README.zh-CN.md
├── SKILL.md                      # OpenClaw skill definition (agent instructions)
├── prompts/
│   └── ai-intel-daily-prompt.md  # The core prompt (customizable)
└── scripts/
    └── apply-stable-cron.sh      # One-command setup
```

## Requirements

- [OpenClaw](https://github.com/openclaw/openclaw) with Telegram channel configured
- [Edge TTS](https://github.com/nicekid1/node-edge-tts) (free, no API key needed)
- Internet access (for source scanning and TTS)

## License

MIT
