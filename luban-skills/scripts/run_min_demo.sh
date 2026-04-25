#!/usr/bin/env bash
# run_min_demo.sh — 鲁班 Skills 最小闭环 demo
# 模拟一个端到端流程：接需求 → 识别类型 → 生成任务卡 → 输出 Hermes 子任务 prompt

set -u
cd "$(dirname "$0")/.." || exit 1

DEMO_INPUT="${1:-帮我根据会议纪要写一封给张总的项目周会邮件}"

echo "== 鲁班 Skills 最小闭环 Demo =="
echo ""
echo "[用户输入]"
echo "  $DEMO_INPUT"
echo ""

echo "[Step 1] 识别任务类型"
CLASSIFY_OUT=$(bash scripts/classify_task.sh "$DEMO_INPUT")
echo "$CLASSIFY_OUT" | sed 's/^/  /'
echo ""

TASK_TYPE=$(echo "$CLASSIFY_OUT" | grep '^TASK_TYPE=' | cut -d= -f2)
DELIVERABLE=$(echo "$CLASSIFY_OUT" | grep '^DELIVERABLE=' | cut -d= -f2)
MIN_LOOP=$(echo "$CLASSIFY_OUT" | grep '^MIN_LOOP=' | cut -d= -f2)

echo "[Step 2] 生成任务卡"
cat <<EOF
  ---
  任务名称: (由 OpenClaw 从输入提炼)
  任务类型: $TASK_TYPE
  最终交付物: $DELIVERABLE
  输入材料: (待补)
  关键约束: (待补)
  风险点: 被旧上下文带偏 / 误把草稿当正式 / 对外发送前未二次确认
  最小闭环动作: $MIN_LOOP
  是否需要 Hermes: 是
  是否需要人工确认: 是（初稿后 / 对外发送前）
  验收标准: 用户可直接复制使用
  ---
EOF
echo ""

echo "[Step 3] 生成 Hermes 子任务 prompt（示意）"
cat <<EOF
  ROLE: 你是 Hermes，在受控边界内执行子任务。
  TASK:
    目标: 完成交付物「${DELIVERABLE}」
    第一动作: ${MIN_LOOP}
  EXECUTION MODEL: Intent → ReAct → Reflect
  OUTPUT: JSON（参考 references/hermes-three-phase-prompt.md 的 OUTPUT SCHEMA）
EOF
echo ""

echo "[Step 4] 用户可见的表达（由 OpenClaw 说给用户）"
echo '  "我先帮你拆成 3 步。先做一个最小版本给你确认方向，然后补正文，最后做格式优化。"'
echo ""

echo "LUBAN_SKILLS_MIN_DEMO_DONE"
