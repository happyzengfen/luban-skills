#!/usr/bin/env bash
# classify_task.sh — 任务类型识别最小 demo
# 输入一句话需求，输出：TASK_TYPE / DELIVERABLE / MIN_LOOP
# 只做关键词级别的规则匹配，作为最小闭环占位，真实版由 OpenClaw 调 Hermes 判断

set -u

if [ $# -lt 1 ]; then
  echo "用法: $0 \"<用户需求一句话>\""
  echo "例子: $0 \"帮我根据这份资料写一封沟通邮件\""
  exit 1
fi

INPUT="$1"

classify() {
  local s="$1"
  case "$s" in
    *邮件*|*汇报*|*方案*|*通知*|*文案*|*总结*|*写*)  echo "写作类" ;;
    *整理*|*纪要*|*归纳*|*提炼*|*梳理*)              echo "整理类" ;;
    *分析*|*对比*|*排查*|*归因*|*评估*)              echo "分析类" ;;
    *规划*|*计划*|*拆解*|*里程碑*|*推进*)            echo "规划类" ;;
    *只读*|*检查*|*校验*|*运行*|*跑*)                echo "执行辅助类" ;;
    *)                                                echo "未分类" ;;
  esac
}

deliverable_for() {
  case "$1" in
    写作类)     echo "可直接使用的成稿（邮件 / 方案 / 通知）" ;;
    整理类)     echo "结构化整理结果 + 行动项" ;;
    分析类)     echo "结论 + 依据 + 建议优先级" ;;
    规划类)     echo "里程碑 + 依赖 + 验收标准" ;;
    执行辅助类) echo "执行进展 + 中间状态 + 下一步" ;;
    *)          echo "（需要进一步澄清）" ;;
  esac
}

min_loop_for() {
  case "$1" in
    写作类)     echo "先提炼 3 个要点 → 出一版简洁初稿" ;;
    整理类)     echo "先读 1 份材料 → 输出样例结构让用户确认" ;;
    分析类)     echo "先看 1 个数据样本 → 输出单点结论样例" ;;
    规划类)     echo "先输出 MVP 里程碑 → 确认方向再扩展" ;;
    执行辅助类) echo "先跑 1 个只读命令 → 确认链路再加动作" ;;
    *)          echo "需要先澄清任务类型，不建议直接执行" ;;
  esac
}

TYPE=$(classify "$INPUT")
DELIV=$(deliverable_for "$TYPE")
LOOP=$(min_loop_for "$TYPE")

echo "TASK_TYPE=$TYPE"
echo "DELIVERABLE=$DELIV"
echo "MIN_LOOP=$LOOP"
echo "LUBAN_SKILLS_DEMO_DONE"
