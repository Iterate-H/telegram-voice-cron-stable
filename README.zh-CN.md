# telegram-voice-cron-stable

一个 [OpenClaw](https://github.com/openclaw/openclaw) Skill，用于稳定 cron 定时任务向 Telegram 投递文字 + 语音的链路。

[English](./README.md) | 中文

## 问题背景

OpenClaw 的 cron announce 管线在向 Telegram 投递时存在已知的静默失败 bug（[#14743](https://github.com/openclaw/openclaw/issues/14743)、[#25670](https://github.com/openclaw/openclaw/issues/25670)、[#31714](https://github.com/openclaw/openclaw/issues/31714)）：

- `delivery.mode=announce` 发出的消息从未到达 Telegram（无任何错误日志）
- 内部中继文本泄漏到用户可见的消息中
- `deliveryStatus` 虚报 `delivered`，实际什么也没发出去

## 解决方案

本 skill 提供一套确定性投递模板，绕过不可靠的 announce 中继：

1. **`delivery.mode=none`** — 完全禁用 Gateway announce 中继
2. **显式发送步骤** — agent 通过 tool call 直接发送文字和语音（`asVoice=true`）
3. **TTS 降级链** — 失败自动重试分段，仍失败则发送精简降级语音兜底

> **更新（v2026.3.11+）：** announce 管线的修复（[PR #31810](https://github.com/openclaw/openclaw/issues/31714)）已在 v2026.3.11 中合入。如果你的版本 >= v2026.3.12，可以用 `delivery.mode=announce` 投递文字，agent 只负责发语音。详见下方[使用方式](#使用方式)。

## 快速开始

```bash
# 克隆
git clone https://github.com/Iterate-H/telegram-voice-cron-stable.git

# 应用到某个 cron job
bash scripts/apply-stable-cron.sh \
  --job-id <cronJobId> \
  --target <telegramChatId> \
  --prompt-file /path/to/your-prompt.md \
  --voice zh-CN-XiaoxiaoNeural

# 测试
openclaw cron run <cronJobId>

# 验证
openclaw cron runs --id <cronJobId> --limit 1
```

## 使用方式

### 模式 A：Agent 全权发送（v2026.3.11 之前，或需要最大控制力）

apply 脚本会设置 `delivery.mode=none`，并注入一套消息模板，agent 执行时：

1. 通过 tool call 发送文字到 Telegram
2. 使用 Edge TTS 生成语音
3. 发送语音气泡（`asVoice=true`）到 Telegram
4. 最终输出 `NO_REPLY`

### 模式 B：Announce 投递文字 + Agent 发送语音（v2026.3.12+，推荐）

升级 OpenClaw 后，将文字投递切换为 announce：

```bash
openclaw cron edit <jobId> \
  --announce \
  --channel telegram \
  --to <chatId> \
  --best-effort-deliver
```

然后修改 agent 消息模板：只发送语音气泡，最终回复输出完整报告文本（announce 自动投递到 Telegram）。

## TTS 失败降级链

模板强制执行严格的降级策略：

| 阶段 | 条件 | 动作 |
|------|------|------|
| 1 | TTS 成功 | 正常发送语音气泡 |
| 2 | 首次失败 | 分段重试（每段 <= 800 字） |
| 3 | 二次失败 | 发送"失败说明"文本到同一聊天 |
| 4 | 降级语音 | 60 秒内发送精简语音（标题 + 3 条行动建议） |

任何路径都不会静默跳过语音——至少产出一条语音气泡。

## 文件结构

```
telegram-voice-cron-stable/
  SKILL.md           # OpenClaw skill 定义（frontmatter + 指令）
  skill-info.json    # Skill 元数据（打包/分发用）
  scripts/
    apply-stable-cron.sh   # 一键配置脚本
  dist/
    telegram-voice-cron-stable.skill   # 打包文件（zip）
```

## 依赖

- [OpenClaw](https://github.com/openclaw/openclaw)（CLI：`openclaw cron edit`、`openclaw cron run`）
- [Edge TTS](https://github.com/nicekid1/node-edge-tts)（通过 node-edge-tts，需联网）
- 具有发送权限的 Telegram Bot

## 许可证

MIT
