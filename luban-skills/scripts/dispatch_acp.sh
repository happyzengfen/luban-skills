#!/usr/bin/env bash
# dispatch_acp.sh — luban 自有 ACP 调度器（不依赖其他 skill）
#
# 职责：
#   1. 用 build_prompt.sh 把任务卡拼成最终 prompt
#   2. 启动 acp_pty_driver.py 驱动 ACP client（无 client 则进 SIM 模式）
#   3. tail stdout，按行级匹配分流事件（thinking / tool_call / error / progress / checkpoint / final）
#   4. tool_call 一律送 guard.py 判定；block 即中止
#   5. 把所有事件记到 runs/<session_id>/events.jsonl
#   6. 关键节点调 notify_feishu.sh 推送飞书卡片
#
# 用法：
#   dispatch_acp.sh start <task_card.yaml> [session_id]
#   dispatch_acp.sh stop  <session_id>
#
# 环境变量：
#   DRY_RUN            true 时只拼 prompt 不真跑
#   ACP_CLIENT_CMD     自定义启动命令（默认 hermes acp，不存在则进 SIM）
#   ACP_TIMEOUT_S      硬超时秒数（默认 1800）
#   GUARD_RULES_PATH   自定义 guard 规则文件
#   LUBAN_NOTIFY       true（默认）发飞书通知

set -euo pipefail

LUBAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTIFY="$LUBAN_DIR/scripts/notify_feishu.sh"
BUILD_PROMPT="$LUBAN_DIR/scripts/build_prompt.sh"
GUARD="$LUBAN_DIR/scripts/guard.py"
PTY_DRIVER="$LUBAN_DIR/scripts/acp_pty_driver.py"

# --- 工具 ---
now_utc()   { date -u +%Y-%m-%dT%H:%M:%S.%3NZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ; }
log_event() {
  local type="$1" payload="$2"
  printf '{"ts":"%s","type":"%s","payload":%s}\n' "$(now_utc)" "$type" "$payload" >> "$EVENTS_LOG"
}
json_str()  { python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"; }
notify()    { [ "${LUBAN_NOTIFY:-true}" = "true" ] && [ -x "$NOTIFY" ] && bash "$NOTIFY" "$@" || true; }

classify_tool_line() {
  local line="$1"
  cmd=""
  kind="noise"

  case "$line" in
    "Tool call:"*|"Running terminal:"*|"执行命令:"*)
      cmd=$(printf '%s' "$line" | sed -E 's/^(Tool call|Running terminal|执行命令):[[:space:]]*//')
      kind="shell"
      ;;
    "[tool] "*":"*)
      local tool_name raw_cmd
      tool_name=$(printf '%s' "$line" | sed -E 's/^\[tool\][[:space:]]+([^:]+):.*$/\1/')
      raw_cmd=$(printf '%s' "$line" | sed -E 's/^\[tool\][[:space:]]+[^:]+:[[:space:]]*//')
      case "$tool_name" in
        pwd|ls|cat|head|tail|wc|grep|find|echo|date|python3|git|bash|sh)
          cmd="$raw_cmd"
          kind="shell"
          ;;
        *)
          kind="acp_tool"
          ;;
      esac
      ;;
  esac

  [ "$kind" != "noise" ]
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

ACTION="${1:-}"
ARG2="${2:-}"
ARG3="${3:-}"

if [ -z "$ACTION" ]; then
  echo "用法: $0 start <task_card.yaml> [session_id] | stop <session_id>" >&2
  exit 2
fi

# --- stop 子命令 ---
if [ "$ACTION" = "stop" ]; then
  SESSION_ID="$ARG2"
  [ -z "$SESSION_ID" ] && { echo "stop 需要 session_id" >&2; exit 2; }
  RUN_DIR="$LUBAN_DIR/runs/$SESSION_ID"
  PID_FILE="$RUN_DIR/client.pid"
  if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null || true
    echo "LUBAN_ACP_STOPPED session=$SESSION_ID pid=$pid"
    notify quarantine "$SESSION_ID" session_id="$SESSION_ID" reason="manual stop"
  else
    echo "no pid file: $PID_FILE"
  fi
  exit 0
fi

# --- start 子命令 ---
if [ "$ACTION" != "start" ]; then
  echo "unknown action: $ACTION" >&2; exit 2
fi

CARD_FILE="$ARG2"
SESSION_ID="${ARG3:-luban-$(date -u +%Y%m%d-%H%M%S)-$$}"

if [ -z "$CARD_FILE" ] || [ ! -f "$CARD_FILE" ]; then
  echo "用法: $0 start <task_card.yaml> [session_id]" >&2
  exit 2
fi

RUN_DIR="$LUBAN_DIR/runs/$SESSION_ID"
mkdir -p "$RUN_DIR"
PROMPT_FILE="$RUN_DIR/prompt.txt"
STDOUT_LOG="$RUN_DIR/stdout.log"
EVENTS_LOG="$RUN_DIR/events.jsonl"
STATE_FILE="$RUN_DIR/state.json"
PID_FILE="$RUN_DIR/client.pid"
: > "$STDOUT_LOG"
: > "$EVENTS_LOG"

echo "[luban] session=$SESSION_ID run_dir=$RUN_DIR"

# --- 拼 prompt ---
bash "$BUILD_PROMPT" "$CARD_FILE" > "$PROMPT_FILE"
PROMPT_LINES=$(wc -l < "$PROMPT_FILE" | tr -d ' ')
echo "[luban] prompt built: $PROMPT_LINES lines"

# task_label + budget 提取（与 build_prompt.sh 的 fallback 解析逻辑保持一致）
_parse_field() {
  python3 - "$CARD_FILE" "$1" "$2" <<'PY'
import sys
card_file, field, default = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    import yaml
    d = yaml.safe_load(open(card_file)) or {}
except Exception:
    d = {}
    for raw in open(card_file):
        line = raw.rstrip()
        if line.startswith(field + ":"):
            v = line.split(":", 1)[1].strip().strip('"').strip("'")
            if v.lstrip("-").isdigit():
                d[field] = int(v)
            else:
                d[field] = v
            break
print(d.get(field, default))
PY
}
TASK_LABEL=$(_parse_field task_label unknown)
BUDGET=$(_parse_field time_budget_s 1200)

# 初始 state
cat > "$STATE_FILE" <<EOF
{"session_id":"$SESSION_ID","started_at":"$(now_utc)","task_label":"$TASK_LABEL","budget_s":$BUDGET,"acp_session_id":null,"status":"starting"}
EOF

# DRY_RUN 短路
if [ "${DRY_RUN:-false}" = "true" ]; then
  echo "[luban] DRY_RUN=true，不启动 client"
  echo "---8<--- prompt begin ---8<---"
  cat "$PROMPT_FILE"
  echo "---8<--- prompt end ---8<---"
  echo "LUBAN_ACP_DRYRUN_OK session=$SESSION_ID"
  exit 0
fi

# --- 启动通知 ---
notify start "$TASK_LABEL" session="$SESSION_ID" budget="${BUDGET}s" mode="luban-self"

# --- 启动 PTY driver 后台跑 ---
ACP_PROMPT_FILE="$PROMPT_FILE" \
ACP_STDOUT_LOG="$STDOUT_LOG" \
ACP_CWD="${ACP_CWD:-$PWD}" \
ACP_TIMEOUT_S="$BUDGET" \
python3 "$PTY_DRIVER" &
CLIENT_PID=$!
echo $CLIENT_PID > "$PID_FILE"
echo "[luban] client pid=$CLIENT_PID"

# --- 主循环：进程替换 + FD3，保证 while 在当前 shell（不丢变量），mac/linux 通用 ---
# 后台监视 client 进程，退出后 kill tail 让主循环自然结束
exec 3< <(
  tail -n +1 -f "$STDOUT_LOG" &
  TAIL_PID=$!
  while kill -0 "$CLIENT_PID" 2>/dev/null; do sleep 0.2; done
  sleep 0.3
  kill "$TAIL_PID" 2>/dev/null || true
  wait "$TAIL_PID" 2>/dev/null || true
)

TOOLS_TOTAL=0
TOOLS_BLOCKED=0

while IFS= read -r line <&3; do
  line="$(printf '%s' "$line" | tr -d '\r')"

  # (a) ACP session id 捕获
  if [[ "$line" =~ Session:[[:space:]]+([0-9a-f-]{36}) ]]; then
    acp_sid="${BASH_REMATCH[1]}"
    python3 - <<PY
import json, pathlib
p = pathlib.Path("$STATE_FILE")
s = json.loads(p.read_text())
s["acp_session_id"] = "$acp_sid"
p.write_text(json.dumps(s))
PY
    log_event session_id_captured "$(json_str "$acp_sid")"
    continue
  fi

  # (b) 工具调用分类：shell 命令 → guard；ACP 内建工具 → 记录但不走 shell guard
  cmd=""
  kind="noise"
  if classify_tool_line "$line"; then
    if [ "$kind" = "acp_tool" ]; then
      log_event tool_call "{\"cmd\":$(json_str "$line"),\"kind\":\"acp_tool\"}"
      continue
    fi

    TOOLS_TOTAL=$((TOOLS_TOTAL+1))
    cmd="${cmd%% (undefined)}"
    cmd="${cmd%% }"
    log_event tool_call "{\"cmd\":$(json_str "$cmd"),\"kind\":\"shell\"}"
    decision=$(python3 "$GUARD" match "$cmd" || true)
    if [ "$decision" != "allow" ]; then
      TOOLS_BLOCKED=$((TOOLS_BLOCKED+1))
      log_event tool_blocked "{\"cmd\":$(json_str "$cmd"),\"kind\":\"shell\",\"reason\":\"guard_rejected\"}"
      notify error "$TASK_LABEL" session="$SESSION_ID" step="tool" message="blocked: $cmd"
      kill $CLIENT_PID 2>/dev/null || true
      break
    fi
    continue
  fi

  # (c) 工具完成 / 失败
  case "$line" in
    "[tool update] "*": completed") log_event tool_done   "{}"; continue ;;
    "[tool update] "*": failed")    log_event tool_failed "{}"; continue ;;
  esac

  # (d) 思考
  case "$line" in
    THINKING*|"🧠"*|"正在查阅"*|"正在生成"*|"正在思考"*)
      log_event thinking "{\"text\":$(json_str "$line")}"
      continue
      ;;
  esac

  # (e) Hermes 自主发出的 EVENT: 行
  case "$line" in
    "EVENT: "*)
      # 切出 event 名（第一个空格后的第一个 token）
      rest="${line#EVENT: }"
      evt="${rest%% *}"
      payload="${rest#* }"
      [ "$payload" = "$rest" ] && payload=""
      log_event "event_${evt}" "{\"raw\":$(json_str "$payload")}"
      case "$evt" in
        progress|checkpoint|reflect|need_confirm)
          notify "$evt" "$TASK_LABEL" session="$SESSION_ID" raw="$payload"
          ;;
      esac
      continue
      ;;
  esac

  # (f) 错误
  case "$line" in
    ERROR*|Traceback*|Exception*)
      log_event error "{\"text\":$(json_str "$line")}"
      notify error "$TASK_LABEL" session="$SESSION_ID" message="$line"
      continue
      ;;
  esac

  # 其它 → noise（已在 stdout.log 里）
done

# --- 等待客户端退出 ---
set +e
wait $CLIENT_PID
EXIT_CODE=$?
set -e
exec 3<&-  # 关闭 fd3
echo "[luban] client exited code=$EXIT_CODE tools=$TOOLS_TOTAL blocked=$TOOLS_BLOCKED"

# --- 更新 state ---
python3 - <<PY
import json, pathlib
p = pathlib.Path("$STATE_FILE")
s = json.loads(p.read_text())
s["status"] = "done" if $EXIT_CODE == 0 else ("blocked" if $TOOLS_BLOCKED > 0 else "failed")
s["exit_code"] = $EXIT_CODE
s["tools_total"] = $TOOLS_TOTAL
s["tools_blocked"] = $TOOLS_BLOCKED
s["finished_at"] = "$(now_utc)"
p.write_text(json.dumps(s, ensure_ascii=False, indent=2))
PY

# --- 完成通知 ---
if [ $EXIT_CODE -eq 0 ]; then
  notify done "$TASK_LABEL" session="$SESSION_ID" run_dir="$RUN_DIR" tools="$TOOLS_TOTAL"
  echo "LUBAN_ACP_OK session=$SESSION_ID run_dir=$RUN_DIR"
else
  if [ $TOOLS_BLOCKED -gt 0 ]; then
    notify blocked "$TASK_LABEL" session="$SESSION_ID" blocked="$TOOLS_BLOCKED"
    echo "LUBAN_ACP_BLOCKED session=$SESSION_ID blocked=$TOOLS_BLOCKED"
  else
    notify error "$TASK_LABEL" session="$SESSION_ID" exit_code="$EXIT_CODE"
    echo "LUBAN_ACP_FAIL session=$SESSION_ID exit=$EXIT_CODE"
  fi
  exit $EXIT_CODE
fi
