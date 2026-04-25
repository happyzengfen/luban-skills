#!/usr/bin/env bash
# verify_run.sh — luban 自有分层验收（链路/事件/工具/状态）
#
# 用法:
#   verify_run.sh <session_id>
#   verify_run.sh <session_id> --strict

set -u

SESSION_ID="${1:-}"
STRICT="${2:-}"

if [ -z "$SESSION_ID" ]; then
  echo "用法: $0 <session_id> [--strict]" >&2
  exit 2
fi

LUBAN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="$LUBAN_DIR/runs/$SESSION_ID"

if [ ! -d "$RUN_DIR" ]; then
  echo "FAIL 找不到 run 目录: $RUN_DIR"
  exit 1
fi

PASS=0; FAIL=0
ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ng() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

echo "=== luban run 验收 ==="
echo "session: $SESSION_ID"
echo "run_dir: $RUN_DIR"
echo ""

# 层 1：链路层（文件完整）
echo "[链路层]"
for f in prompt.txt stdout.log events.jsonl state.json; do
  [ -f "$RUN_DIR/$f" ] && ok "$f 存在" || ng "$f 缺失"
done

# 层 2：事件层（有关键事件）
echo ""
echo "[事件层]"
if [ -f "$RUN_DIR/events.jsonl" ]; then
  total=$(wc -l < "$RUN_DIR/events.jsonl" | tr -d ' ')
  ok "事件总数 $total"
  for t in session_id_captured thinking; do
    if grep -q "\"type\":\"$t\"" "$RUN_DIR/events.jsonl" 2>/dev/null; then
      ok "事件类型 $t 出现"
    else
      [ "$STRICT" = "--strict" ] && ng "缺少事件 $t" || echo "  ⚠️  缺少事件 $t（非严格模式跳过）"
    fi
  done
fi

# 层 3：工具层（guard 审批）
echo ""
echo "[工具层]"
if [ -f "$RUN_DIR/events.jsonl" ]; then
  tools=$(grep -c "\"type\":\"tool_call\"" "$RUN_DIR/events.jsonl" 2>/dev/null || echo 0)
  blocked=$(grep -c "\"type\":\"tool_blocked\"" "$RUN_DIR/events.jsonl" 2>/dev/null || echo 0)
  ok "工具调用数 $tools / 阻断数 $blocked"
fi

# 层 4：状态层（state.json 合法）
echo ""
echo "[状态层]"
if [ -f "$RUN_DIR/state.json" ]; then
  if python3 -c "import json,sys; json.load(open('$RUN_DIR/state.json'))" 2>/dev/null; then
    ok "state.json 是合法 JSON"
    status=$(python3 -c "import json; print(json.load(open('$RUN_DIR/state.json')).get('status','?'))")
    ok "status=$status"
    if [ "$STRICT" = "--strict" ] && [ "$status" != "done" ]; then
      ng "严格模式要求 status=done"
    fi
  else
    ng "state.json 不是合法 JSON"
  fi
fi

# 层 5：污染层（确保没引入外部旧工件痕迹）
echo ""
echo "[污染层]"
if [ -f "$RUN_DIR/stdout.log" ]; then
  if grep -qE "qikang-report|finance/|xpostmast-old" "$RUN_DIR/stdout.log" 2>/dev/null; then
    ng "stdout 含外部旧工件关键词"
  else
    ok "stdout 无旧工件污染关键词"
  fi
fi

echo ""
echo "==========================="
echo "  PASS: $PASS  FAIL: $FAIL"
echo "==========================="
if [ "$FAIL" -eq 0 ]; then
  echo "LUBAN_VERIFY_OK"; exit 0
else
  echo "LUBAN_VERIFY_FAIL"; exit 1
fi
