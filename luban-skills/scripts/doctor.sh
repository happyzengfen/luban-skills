#!/usr/bin/env bash
# doctor.sh — 鲁班 Skills 一键自检
# 检查 skill 文件完整性，不依赖运行时环境

set -u
cd "$(dirname "$0")/.." || exit 1

PASS=0
FAIL=0

ok() { echo "  ✅ $1"; PASS=$((PASS+1)); }
ng() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }

check_file() {
  if [ -f "$1" ]; then ok "$1"; else ng "$1 MISSING"; fi
}

check_dir() {
  if [ -d "$1" ]; then ok "$1/"; else ng "$1/ MISSING"; fi
}

echo "== 鲁班 Skills Doctor =="
echo ""
echo "[1/4] 核心文件"
check_file "SKILL.md"
check_file "_meta.json"
check_file "QUICKSTART.md"

echo ""
echo "[2/4] references/"
check_dir  "references"
check_file "references/task-card-template.md"
check_file "references/delivery-templates.md"
check_file "references/hermes-three-phase-prompt.md"
check_file "references/user-facing-language.md"
check_file "references/safety-boundary.md"
check_file "references/acp-long-task-checklist.md"
check_file "references/feishu-notification.md"
check_file "references/llm-behavior-rules.md"
check_file "references/allowlist-default.yaml"

echo ""
echo "[3/4] scripts/"
check_dir  "scripts"
check_file "scripts/doctor.sh"
check_file "scripts/classify_task.sh"
check_file "scripts/notify_feishu.sh"
check_file "scripts/run_min_demo.sh"
check_file "scripts/build_prompt.sh"
check_file "scripts/acp_pty_driver.py"
check_file "scripts/guard.py"
check_file "scripts/dispatch_acp.sh"
check_file "scripts/verify_run.sh"

echo ""
echo "[4/4] examples/"
check_dir  "examples"
check_file "examples/example-write-email.md"
check_file "examples/example-organize-docs.md"
check_file "examples/example-plan-project.md"
check_file "examples/task-card-example.yaml"

echo ""
echo "==========================="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "==========================="

if [ "$FAIL" -eq 0 ]; then
  echo "LUBAN_SKILLS_DOCTOR_OK"
  exit 0
else
  echo "LUBAN_SKILLS_DOCTOR_FAIL"
  exit 1
fi
