#!/usr/bin/env bash
# notify_feishu.sh — ACP 生命周期事件推送到飞书 webhook
#
# 用法:
#   notify_feishu.sh <event> <task_label> [extra_kv...]
#
# event 取值（与 references/feishu-notification.md 对齐）:
#   start         任务启动
#   progress      ReAct 中间进度
#   checkpoint    中间产物已落盘
#   reflect       Reflect 节点（需要决策或观察）
#   need_confirm  请求用户确认
#   retry         触发重试
#   timeout       单次超时
#   quarantine    会话被隔离 / thread binding 解绑
#   done          任务完成
#   blocked       任务卡住
#   error         异常退出
#
# 例子:
#   notify_feishu.sh start  "github-analyze"  goal="拉 awesome-gpt-image-2-prompts" budget="1200s"
#   notify_feishu.sh progress "github-analyze" step="3/8" elapsed="120s" last="拉取 README"
#   notify_feishu.sh timeout "github-analyze" attempt="2/3" elapsed_s="600"
#
# 依赖:
#   FEISHU_WEBHOOK_URL 环境变量；如果未设置则尝试从同级 .env 或 diting-skills/.env 加载

set -u

# ---- 加载 webhook url ----
load_env() {
  local f
  for f in \
    "$(dirname "$0")/../.env" \
    "$(dirname "$0")/../../diting-skills/.env" \
    "$HOME/.openclaw/.env"; do
    if [ -f "$f" ] && [ -z "${FEISHU_WEBHOOK_URL:-}" ]; then
      # shellcheck disable=SC1090
      set -a; . "$f"; set +a
    fi
  done
}
load_env

if [ -z "${FEISHU_WEBHOOK_URL:-}" ]; then
  echo "ERROR: FEISHU_WEBHOOK_URL 未设置（环境变量或 .env 都没有）" >&2
  exit 2
fi

# ---- 入参 ----
if [ $# -lt 2 ]; then
  echo "用法: $0 <event> <task_label> [k=v ...]" >&2
  exit 1
fi

EVENT="$1"; shift
LABEL="$1"; shift

# ---- 事件元数据：颜色 / 表情 / 标题 ----
case "$EVENT" in
  start)         COLOR="blue";    EMOJI="🚀"; TITLE="ACP 任务启动" ;;
  progress)     COLOR="grey";    EMOJI="⏳"; TITLE="ACP 进度更新" ;;
  checkpoint)   COLOR="turquoise"; EMOJI="📦"; TITLE="ACP Checkpoint 已落盘" ;;
  reflect)       COLOR="indigo";   EMOJI="🪞"; TITLE="ACP Reflect 节点" ;;
  need_confirm)  COLOR="yellow";  EMOJI="❓"; TITLE="ACP 请求用户确认" ;;
  retry)        COLOR="orange";  EMOJI="🔁"; TITLE="ACP 触发重试" ;;
  timeout)       COLOR="orange";  EMOJI="⏰"; TITLE="ACP 单次超时" ;;
  quarantine)   COLOR="red";     EMOJI="🚧"; TITLE="ACP 会话已隔离" ;;
  done)         COLOR="green";   EMOJI="✅"; TITLE="ACP 任务完成" ;;
  blocked)       COLOR="red";     EMOJI="⛔"; TITLE="ACP 任务卡住" ;;
  error)         COLOR="red";     EMOJI="❌"; TITLE="ACP 异常退出" ;;
  *)             COLOR="grey";    EMOJI="ℹ️"; TITLE="ACP 事件: $EVENT" ;;
esac

HOST="$(hostname 2>/dev/null || echo unknown)"
TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# ---- 把 k=v 转成 markdown 字段 ----
FIELDS_MD=""
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  # 转义 markdown 关键字符
  v_escaped="$(printf '%s' "$v" | sed 's/"/\\"/g')"
  FIELDS_MD="${FIELDS_MD}**${k}**: ${v_escaped}\n"
done

# ---- 拼飞书 interactive 卡片 ----
read -r -d '' PAYLOAD <<JSON || true
{
  "msg_type": "interactive",
  "card": {
    "config": {"wide_screen_mode": true},
    "header": {
      "template": "${COLOR}",
      "title": {"tag": "plain_text", "content": "${EMOJI} ${TITLE} — ${LABEL}"}
    },
    "elements": [
      {
        "tag": "div",
        "text": {
          "tag": "lark_md",
          "content": "${FIELDS_MD}"
        }
      },
      {
        "tag": "hr"
      },
      {
        "tag": "note",
        "elements": [
          {"tag": "plain_text", "content": "host: ${HOST} · ${TS}"}
        ]
      }
    ]
  }
}
JSON

# ---- 发送（5s 超时；失败不阻塞调用方）----
HTTP_CODE=$(curl -sS -o /tmp/feishu_notify_resp.txt -w '%{http_code}' \
  --max-time 5 \
  -H 'Content-Type: application/json' \
  -X POST "${FEISHU_WEBHOOK_URL}" \
  -d "${PAYLOAD}" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo "FEISHU_NOTIFY_OK event=${EVENT} label=${LABEL}"
  exit 0
else
  echo "FEISHU_NOTIFY_FAIL http=${HTTP_CODE} event=${EVENT} label=${LABEL}" >&2
  cat /tmp/feishu_notify_resp.txt 2>/dev/null >&2 || true
  # 通知失败不应阻塞主流程
  exit 0
fi
