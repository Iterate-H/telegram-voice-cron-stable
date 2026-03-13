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

OpenClaw cron announce 管线在投递 Telegram 时存在已知的静默失败问题（Issue #14743, #25670）：Gateway 的 announce relay 可能丢失消息或泄漏内部中继文本。本 skill 通过三步绕过该问题：

1. 将 cron delivery mode 设为 `none`，禁用 Gateway announce relay
2. 在 agent 指令中直接写死 send 步骤（先文字、再语音）
3. TTS 失败时自动降级：重试分段 → 失败说明 + 精简语音兜底

## When to trigger

当满足以下任一条件时应用本 skill：

- Cron job 需要同时发送**文本 + 语音气泡**到 Telegram
- 使用 announce delivery 后 Telegram 侧无响应（静默失败）
- 用户报告收到内部 relay 文本而非预期内容
- 需要 TTS 失败时的自动兜底机制

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

TTS 失败兜底遵循严格的降级链：

1. **首次失败** → 自动重试，将文本分段（每段 <= 800 字）逐段生成
2. **二次失败** → 立即发送"失败说明"文本到同一 Telegram 聊天
3. **降级语音** → 60 秒内发送精简语音（仅标题 + 3 条行动建议），仍使用 `asVoice=true`
4. **禁止漏发** → 任何路径都必须产出至少一条语音气泡，不允许静默跳过

## Verify checklist

- `delivery.mode` is `none`
- Telegram receives text
- Telegram receives voice bubble (not generic audio file)
- No internal relay text appears in user-visible messages
- On TTS error, user receives explicit failure + degraded voice

## Troubleshooting

| 现象 | 排查方向 |
|------|---------|
| Telegram 无任何消息 | 检查 `openclaw cron runs` 日志，确认 job 是否执行；检查 target chat ID 是否正确 |
| 收到文字但无语音 | 检查 Edge TTS 服务可达性；确认 `asVoice=true` 在 send 参数中 |
| 语音是文件而非气泡 | 确认使用 `asVoice=true` 而非普通 media send |
| 出现内部 relay 文本 | `delivery.mode` 未设为 `none`，重新运行 apply 脚本 |
| apply 脚本报错 | 确认 `openclaw` CLI 已安装且在 PATH 中；检查 prompt 文件路径是否绝对路径 |

## Notes

- 依赖 `openclaw` CLI（`openclaw cron edit`, `openclaw cron run`, `openclaw cron show`）
- 依赖 Edge TTS 服务（通过 node-edge-tts），需要网络连接
- 默认语音：`zh-CN-XiaoxiaoNeural`，可通过 `--voice` 参数更换
- 本 skill 不修改 cron schedule 和 timeout，仅替换 message 模板和 delivery mode
- 已知限制：若 Telegram Bot Token 失效或聊天权限变更，send 步骤本身会失败，不在本 skill 兜底范围内
