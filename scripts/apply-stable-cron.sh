#!/usr/bin/env bash
# ------------------------------------------------------------------
# apply-stable-cron.sh
#
# Purpose: Apply the stable Telegram text+voice delivery template
#          to an OpenClaw cron job, bypassing the announce relay.
#
# Usage:
#   bash apply-stable-cron.sh \
#     --job-id <cronJobId> \
#     --target <telegramChatId> \
#     --prompt-file <absolute-prompt-path> \
#     [--voice zh-CN-XiaoxiaoNeural]
#
# Author: moltbot
# ------------------------------------------------------------------
set -euo pipefail

# --- Dependency check ---
if ! command -v openclaw &>/dev/null; then
  echo "Error: 'openclaw' CLI not found in PATH." >&2
  echo "Install it first or add its directory to PATH." >&2
  exit 1
fi

JOB_ID=""
TARGET=""
PROMPT_FILE=""
VOICE="zh-CN-XiaoxiaoNeural"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job-id) JOB_ID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --voice) VOICE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$JOB_ID" || -z "$TARGET" || -z "$PROMPT_FILE" ]]; then
  echo "Usage: $0 --job-id <id> --target <telegram_chat_id> --prompt-file <abs_path> [--voice zh-CN-XiaoxiaoNeural]" >&2
  exit 1
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

read -r -d '' TEMPLATE <<'EOF' || true
你将生成一份"AI 效率日报"（过去24小时），严格遵循提示文件，并先完成发送动作。

请先读取并遵循：__PROMPT_FILE__

发送流程（稳定优先，必须执行）：
- 先发送文字版到 Telegram: __TARGET__。
- 再发送语音音条（asVoice=true）。

语音稳定性规则（硬约束）：
1) 使用 Edge TTS 固定音色：__VOICE__。
2) 先生成"可朗读文本 spoken_text"：
   - 删除/改写所有代码块、反引号、命令符号（如 &&、||、|、;）
   - 链接改为"可读短句（见文字版）"，不要朗读完整 URL
   - 保留核心信息，不改变结论
3) 若首次语音生成失败：自动重试一次（分段，每段 <= 800 字）。
4) 若二次仍失败：必须立刻发送一条"失败说明"文本到同一 Telegram，并在 60 秒内发送一条"降级语音"（只读：标题+3条行动建议），仍需 asVoice=true，禁止漏发语音。
5) 语音 caption 固定：AI 效率日报（语音朗读）。

完成全部发送后，你的最终回复只输出：NO_REPLY
EOF

MSG="${TEMPLATE//__PROMPT_FILE__/$PROMPT_FILE}"
MSG="${MSG//__TARGET__/$TARGET}"
MSG="${MSG//__VOICE__/$VOICE}"

openclaw cron edit "$JOB_ID" --message "$MSG" --no-deliver

echo ""
echo "Updated cron job: $JOB_ID"
echo "- target: $TARGET"
echo "- prompt: $PROMPT_FILE"
echo "- voice:  $VOICE"
echo "- delivery.mode: none"
echo ""
echo "--- Final cron config ---"
openclaw cron show "$JOB_ID"
