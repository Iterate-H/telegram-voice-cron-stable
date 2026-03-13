# AI 效率日报

[English](./README.md) | 中文

每天早上 8:30，自动扫一遍全球 AI 动态，过滤掉炒作和噪音，把真正有用的东西整理成一份日报，文字 + 语音推送到你的 Telegram。

基于 [OpenClaw](https://github.com/openclaw/openclaw) + [Edge TTS](https://github.com/nicekid1/node-edge-tts)。

## 每天收到什么

一份结构化日报。文字版直接看，语音版通勤路上听：

- **核心关注**（0–2 条）：真正的技术突破或马上能用的工具，附带"今天就能做的一步"
- **工具箱更新**（3–6 条）：实用的开源项目和工具，每条都标了使用场景和来源靠不靠谱
- **降噪区**：今天刷屏但不值得看的东西
- **3 条行动建议**：具体到一个命令、一个链接、一个设置

## 反炒作

这份日报的核心原则是**只讲事实，不贩卖焦虑**：

- **留下**：模型/架构突破、马上能用的工具和插件、有代码有 Demo 的开源项目
- **扔掉**：纯观点、没代码的 PPT 产品、股价波动、营销号标题党
- **来源打分**：每条标注可信度——官方 repo（S）> 活跃开源（A）> 榜单聚合（B）> 个人转载（C）
- **S 级条目必须可验证**：抓不到官方原文的，直接降级或丢弃

## 怎么跑起来的

```
 定时触发        AI 搜索 + 抓取       筛选分级          推送到手机
┌─────────┐    ┌──────────────┐    ┌───────────┐    ┌───────────┐
│ 每天8:30 │──▶│ 搜 5 类数据源 │──▶│ 反炒作过滤 │──▶│ 文字+语音  │
│ 自动启动  │    │ 官方源交叉验证 │    │ 按S/B/C分级│    │ 到 Telegram│
└─────────┘    └──────────────┘    └───────────┘    └───────────┘
```

1. OpenClaw 每天定时启动一个独立的 AI 会话
2. AI 按照 [prompt](./prompts/ai-intel-daily-prompt.md) 搜索 GitHub Trending、HuggingFace、官方博客等 5 类来源，逐条验证
3. 生成结构化日报，附带可执行的行动建议
4. 文字版自动推送到 Telegram，同时用 Edge TTS 生成语音版一起发过去
5. 语音生成失败？自动重试，再失败发一条精简版语音保底——不会漏发

## 快速开始

### 1. 创建定时任务

```bash
openclaw cron add \
  --name "ai-intel:daily-0830" \
  --cron "30 8 * * *" \
  --tz "Asia/Shanghai" \
  --session isolated \
  --announce \
  --channel telegram \
  --to <你的 Telegram Chat ID> \
  --best-effort-deliver \
  --timeout-seconds 900
```

### 2. 配置日报模板

```bash
bash scripts/apply-stable-cron.sh \
  --job-id <任务ID> \
  --target <你的 Telegram Chat ID> \
  --prompt-file /absolute/path/to/prompts/ai-intel-daily-prompt.md \
  --voice zh-CN-XiaoxiaoNeural
```

### 3. 跑一次试试

```bash
openclaw cron run <任务ID>
openclaw cron runs --id <任务ID> --limit 1
```

去 Telegram 看看有没有收到文字 + 圆形语音气泡。

## 按你的需求改

### 改内容：编辑 Prompt

编辑 [`prompts/ai-intel-daily-prompt.md`](./prompts/ai-intel-daily-prompt.md)：

- **换数据源**：增删白名单里的网站
- **换筛选标准**：根据你的领域重新定义什么算"核心关注"
- **换输出格式**：调整章节结构
- **换语言**：把输出格式改成英文就能生成英文日报

### 换语音

```bash
--voice zh-CN-XiaoxiaoNeural    # 中文女声（默认）
--voice zh-CN-YunxiNeural       # 中文男声
--voice en-US-AriaNeural        # 英文女声
```

### 换时间

```bash
openclaw cron edit <任务ID> --cron "0 9 * * *"    # 改成每天 9 点
openclaw cron edit <任务ID> --cron "0 9 * * 1-5"  # 只在工作日发
```

## 消息推送稳定性

OpenClaw 的定时消息推送到 Telegram 有已知的 bug——消息发了但 Telegram 收不到，也没有报错（[#14743](https://github.com/openclaw/openclaw/issues/14743)、[#25670](https://github.com/openclaw/openclaw/issues/25670)、[#31714](https://github.com/openclaw/openclaw/issues/31714)）。

本项目已经处理了这个问题：

- **OpenClaw v2026.3.12+**（推荐）：官方已修复，用 `--announce` 模式即可
- **旧版本**：脚本会自动绕过有问题的推送通道，由 AI 直接发消息到 Telegram

### 语音发送失败怎么办

| 阶段 | 发生了什么 | 系统会做什么 |
|------|-----------|------------|
| 1 | 语音生成成功 | 正常发送 |
| 2 | 第一次失败 | 把长文本拆成短段重试 |
| 3 | 还是失败 | 先发一条"语音生成失败"的文字通知 |
| 4 | 保底 | 60 秒内发一条精简版语音（只读标题和 3 条建议） |

**不会出现"语音没了也没通知"的情况。**

## 文件说明

```
├── prompts/
│   └── ai-intel-daily-prompt.md  ← 核心 prompt，改这个就能改日报内容
├── scripts/
│   └── apply-stable-cron.sh      ← 一键配置脚本
└── SKILL.md                      ← OpenClaw skill 定义文件（给 agent 读的指令）
```

## 需要什么

- [OpenClaw](https://github.com/openclaw/openclaw)，配好 Telegram 机器人
- [Edge TTS](https://github.com/nicekid1/node-edge-tts)，免费，不需要 API Key
- 能联网（搜索数据源 + 生成语音都需要）

## License

MIT
