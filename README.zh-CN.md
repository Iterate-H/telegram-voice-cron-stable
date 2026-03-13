# AI 效率日报（自动化情报管线）

[English](./README.md) | 中文

全自动 AI 情报管线：每天扫描全球 AI 动态，过滤炒作噪音，生成结构化文字 + 语音日报，推送到 Telegram。

基于 [OpenClaw](https://github.com/openclaw/openclaw) + [Edge TTS](https://github.com/nicekid1/node-edge-tts) 构建。

## 你能得到什么

每天早上 08:30，Telegram 收到一份结构化日报——文字版可读，语音气泡可以通勤路上听：

- **S 级核心关注**（0–2 条）：经过验证的技术突破或立即可用的工具，附带行动步骤
- **B 级工具箱更新**（3–6 条）：实用工具/开源项目，每条标注使用场景和来源可信度
- **行业降噪**：今天可以忽略什么、为什么
- **3 条行动建议**：今天就能执行的具体下一步

## 反炒作原则

Prompt 强制执行严格的筛选标准：

- **保留**：基座模型/技术突破（A 类）、立刻可用的提效工具/插件/开源项目（B 类）
- **丢弃**：纯观点输出、无 Demo/无代码的 "PPT 产品"、股市波动、营销号惊悚标题
- **来源可信度评级**：每条标注 S/A/B/C（官方 repo > 高星活跃开源 > 聚合榜单 > 个人二次转载）
- **验证要求**：S 级条目必须能从官方源抓取到可验证文本，否则降级或丢弃

## 工作流程

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│ Cron 08:30  │────▶│ Agent 扫描   │────▶│ 筛选/分级    │────▶│ Telegram │
│ (OpenClaw)  │     │ 多源检索     │     │ 反炒作过滤   │     │ 文字 +   │
│             │     │ (web_search  │     │ S/B/C/D 分级 │     │ 语音 🔊  │
│             │     │ + web_fetch) │     │              │     │          │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
```

1. **OpenClaw cron** 每天触发一个隔离 agent 会话
2. **Agent** 执行 [prompt](./prompts/ai-intel-daily-prompt.md)：搜索 5 类数据源，交叉验证官方链接
3. **日报** 按结构化格式生成，包含可执行的行动建议
4. **投递**：文字通过 announce 投递，语音通过 Edge TTS 生成（`asVoice=true`）
5. **TTS 兜底**：分段重试 → 失败说明 → 降级精简语音（永不静默失败）

## 快速开始

### 1. 在 OpenClaw 中创建 cron job

```bash
openclaw cron add \
  --name "ai-intel:daily-0830" \
  --cron "30 8 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --announce \
  --channel telegram \
  --to <你的telegram-chat-id> \
  --best-effort-deliver \
  --timeout-seconds 900
```

### 2. 应用稳定投递模板

```bash
bash scripts/apply-stable-cron.sh \
  --job-id <cronJobId> \
  --target <你的telegram-chat-id> \
  --prompt-file /absolute/path/to/prompts/ai-intel-daily-prompt.md \
  --voice zh-CN-XiaoxiaoNeural
```

### 3. 测试

```bash
openclaw cron run <cronJobId>
openclaw cron runs --id <cronJobId> --limit 1
```

检查 Telegram 是否收到文字消息 + 圆形语音气泡。

## 自定义

### 修改 Prompt

编辑 [`prompts/ai-intel-daily-prompt.md`](./prompts/ai-intel-daily-prompt.md)，可调整：

- **数据源**：增删白名单（GitHub、HuggingFace、官方博客等）
- **筛选标准**：根据你的领域调整 S 级和噪音的定义
- **输出格式**：调整章节结构、匹配你的阅读习惯
- **语言**：prompt 是中文的，但换成英文输出格式即可生成英文日报

### 切换语音

```bash
# 常用语音
--voice zh-CN-XiaoxiaoNeural    # 中文女声（默认）
--voice zh-CN-YunxiNeural       # 中文男声
--voice en-US-AriaNeural        # 英文女声
```

### 修改时间

```bash
openclaw cron edit <jobId> --cron "0 9 * * *"    # 每天 09:00
openclaw cron edit <jobId> --cron "0 9 * * 1-5"  # 仅工作日
```

## 投递稳定性

本项目包含对 OpenClaw announce 投递已知 bug 的解决方案（[#14743](https://github.com/openclaw/openclaw/issues/14743)、[#25670](https://github.com/openclaw/openclaw/issues/25670)、[#31714](https://github.com/openclaw/openclaw/issues/31714)），这些 bug 会导致 Telegram 消息静默丢失。

**OpenClaw v2026.3.12+**（推荐）：直接使用 `--announce` 模式，修复已包含在内。

**旧版本**：apply 脚本会设置 `delivery.mode=none`，agent 通过 tool call 直接发送文字和语音，绕过损坏的 announce 管线。

### TTS 降级链

| 阶段 | 条件 | 动作 |
|------|------|------|
| 1 | TTS 成功 | 正常发送语音气泡 |
| 2 | 首次失败 | 分段重试（每段 <= 800 字） |
| 3 | 二次失败 | 发送"失败说明"文本 |
| 4 | 降级语音 | 60 秒内发送精简语音（标题 + 3 条建议） |

任何路径都不会静默跳过语音——至少产出一条语音气泡。

## 文件结构

```
├── README.md
├── README.zh-CN.md
├── SKILL.md                    # OpenClaw skill 定义
├── skill-info.json             # Skill 元数据
├── prompts/
│   └── ai-intel-daily-prompt.md  # 核心 prompt（可自定义）
├── scripts/
│   └── apply-stable-cron.sh      # 一键配置脚本
└── dist/
    └── telegram-voice-cron-stable.skill  # 打包文件（zip）
```

## 依赖

- [OpenClaw](https://github.com/openclaw/openclaw)（需配置 Telegram 频道）
- [Edge TTS](https://github.com/nicekid1/node-edge-tts)（免费，无需 API Key）
- 网络连接（用于源扫描和 TTS）

## 许可证

MIT
