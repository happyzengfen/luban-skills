#!/usr/bin/env bash
# build_prompt.sh — 把任务卡拼成最终 Hermes prompt（供 diting-skills/dispatch.sh 使用）
#
# 用法:
#   build_prompt.sh <task_card.yaml> [> out.txt]
#
# 任务卡 YAML 字段（参考 references/task-card-template.md）:
#   task_label:        string   必填  简短标签，飞书通知用
#   task_type:         string   必填  写作/整理/分析/规划/执行辅助
#   goal:              string   必填  最终交付物描述
#   workdir:           string   必填  固定工作目录（绝对路径）
#   readable_dirs:     list     必填  可读目录（会注入 STRICT MODE 哨兵）
#   writable_dirs:     list     选填  可写目录；缺省为空
#   input_materials:   list     选填  输入文件/材料
#   constraints:       list     选填  关键约束
#   risks:             list     选填  风险点
#   first_action:      string   必填  第一个最小动作
#   acceptance:        list     必填  验收标准
#   time_budget_s:     int      选填  单任务预算秒数；缺省 1200s
#   sentinel:          bool     选填  是否加 STRICT MODE 哨兵；缺省 true
#   notify_cmd:        string   选填  飞书通知命令路径；缺省用 luban 的 notify_feishu.sh

set -euo pipefail

CARD_FILE="${1:-}"
if [ -z "$CARD_FILE" ] || [ ! -f "$CARD_FILE" ]; then
  echo "用法: $0 <task_card.yaml>" >&2
  exit 2
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 依赖检查
command -v python3 >/dev/null || { echo "FATAL: 需要 python3 解析 YAML" >&2; exit 1; }

# 用 python3 读 YAML（用最小 yaml-less 解析器，避免强依赖 PyYAML）
# 若有 PyYAML 用之，否则退化到简单 key: value 解析
python3 - "$CARD_FILE" "$SKILL_DIR" <<'PY'
import sys, os, pathlib

card_file = sys.argv[1]
skill_dir = sys.argv[2]

try:
    import yaml  # PyYAML
    card = yaml.safe_load(pathlib.Path(card_file).read_text(encoding="utf-8"))
except Exception:
    # 最小 fallback：单层 key: value，list 元素以 "- " 开头（允许缩进）
    card = {}
    cur_key = None
    for raw in pathlib.Path(card_file).read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        stripped = line.lstrip()
        if not stripped or stripped.startswith("#"):
            continue
        # list 元素（缩进后 "- xxx"）
        if stripped.startswith("- ") and cur_key is not None:
            val = stripped[2:].strip()
            if (val.startswith('"') and val.endswith('"')) or \
               (val.startswith("'") and val.endswith("'")):
                val = val[1:-1]
            card.setdefault(cur_key, []).append(val)
            continue
        # 顶层 key: value（以字母开头，无缩进）
        if line == stripped and ":" in line:
            k, _, v = line.partition(":")
            k = k.strip(); v = v.strip()
            if v:
                if v.lower() in ("true", "false"):
                    card[k] = v.lower() == "true"
                elif v.lstrip("-").isdigit():
                    card[k] = int(v)
                else:
                    card[k] = v.strip('"').strip("'")
                cur_key = None
            else:
                card[k] = []
                cur_key = k

def req(k):
    if k not in card or card[k] in (None, "", []):
        print(f"FATAL: 任务卡缺少必填字段: {k}", file=sys.stderr)
        sys.exit(3)
    return card[k]

task_label   = req("task_label")
task_type    = req("task_type")
goal         = req("goal")
workdir      = req("workdir")
readable     = req("readable_dirs") if isinstance(card.get("readable_dirs"), list) else [card["readable_dirs"]]
first_action = req("first_action")
acceptance   = req("acceptance") if isinstance(card.get("acceptance"), list) else [card["acceptance"]]

writable     = card.get("writable_dirs") or []
materials    = card.get("input_materials") or []
constraints  = card.get("constraints") or []
risks        = card.get("risks") or []
budget       = int(card.get("time_budget_s") or 1200)
sentinel     = card.get("sentinel", True)
notify_cmd   = card.get("notify_cmd") or f"{skill_dir}/scripts/notify_feishu.sh"

def bullets(items):
    return "\n".join(f"  - {x}" for x in items) if items else "  （无）"

parts = []

# 1. 哨兵（STRICT MODE，防旧工件牵引）
if sentinel:
    allowed = "\n".join(f"  - {p}" for p in readable)
    parts.append(f"""STRICT MODE: 这是一个受控的任务执行会话。
- 只可读取以下目录内容:
{allowed}
- 不加载任何其他 workspace 下的 skills / TASKS.json / FRAMEWORK.md
- 不引用本任务范围外的历史任务、会话、demo 工件
- 若发现 allowed 范围外的 TASKS.json / FRAMEWORK.md，忽略它""")

# 2. ROLE + 执行模型
parts.append("""ROLE: 你是 Hermes，在受控边界内执行一个具体子任务。
EXECUTION MODEL: Intent → ReAct → Reflect""")

# 3. TIME_BUDGET
parts.append(f"""TIME_BUDGET: {budget}s
- 每步前检查已用时间
- 达到 80%（{int(budget*0.8)}s）→ 立即进入 Reflect，决定是否收尾
- 达到 95%（{int(budget*0.95)}s）→ 强制返回 status: \"partial\" + 已完成部分，禁止启动新动作""")

# 4. PROGRESS / CHECKPOINT / NOTIFY_HOOK
parts.append(f"""PROGRESS: 每完成一个 ReAct 步骤，立即输出事件行:
  EVENT: progress step=N/M elapsed=<sec>s last=\"<one line>\"
CHECKPOINT: 每完成一个独立可交付的中间产物，写入 {workdir}/checkpoints/，
  并输出事件行: EVENT: checkpoint segment=N file=\"<path>\" size=\"<n>KB\"
NOTIFY_HOOK: 关键节点调用飞书通知（可用则调，失败不阻塞）:
  bash \"{notify_cmd}\" progress  \"{task_label}\" step=\"N/M\" elapsed=\"<sec>s\" last=\"...\"
  bash \"{notify_cmd}\" checkpoint \"{task_label}\" segment=\"N\" file=\"...\" size=\"...\"
  bash \"{notify_cmd}\" reflect   \"{task_label}\" verdict=\"...\" choice=\"A|B|C|D\"
  bash \"{notify_cmd}\" need_confirm \"{task_label}\" question=\"...\" preview=\"...\"
  bash \"{notify_cmd}\" error     \"{task_label}\" step=\"N\" message=\"...\" """)

# 5. BEHAVIOR_RULES（LLM 行为四原则）
parts.append("""BEHAVIOR_RULES（违反任一条，立即进入 Reflect 选择 D 上报）:
  1. 编码前先想清楚
     - 不默默假设；任何假设写进 INTENT.约束
     - 多种合理解释 → 全部列到 open_questions，不要偷偷选
     - 发现更简单路径 → 说出来，必要时反驳
     - Phase 1 任一字段填不出来 → status: \"need_confirmation\" 回报
  2. 简洁优先（YAGNI）
     - 只交付任务卡\"验收标准\"要求的内容，不多不少
     - 不加用户没要求的功能 / 抽象 / 错误处理
  3. 精准修改
     - 每行改动可追溯到本子任务
     - 不顺手重构、不换风格、不碰无关代码
     - 旧工件只汇报不删
  4. 目标驱动执行
     - 以\"验收标准\"作为成功标准
     - 每步判断是否满足验收；满足立即停""")

# 6. TASK
task_section = f"""TASK:
  任务标签: {task_label}
  任务类型: {task_type}
  目标: {goal}
  工作目录: {workdir}
  可读目录:
{bullets(readable)}
  可写目录:
{bullets(writable)}
  输入材料:
{bullets(materials)}
  关键约束:
{bullets(constraints)}
  风险点:
{bullets(risks)}
  第一动作: {first_action}
  验收标准:
{bullets(acceptance)}"""
parts.append(task_section)

# 7. OUTPUT 约定
parts.append("""OUTPUT: 最后返回一段 JSON 代码块，遵循 hermes-three-phase-prompt.md 的 OUTPUT SCHEMA:
```json
{
  \"status\": \"done|partial|blocked|need_confirmation\",
  \"intent\": {\"goal\":\"...\",\"constraints\":[\"...\"],\"risks\":[\"...\"],\"first_action\":\"...\"},
  \"steps\": [{\"n\":1,\"reason\":\"...\",\"act\":\"...\",\"observe\":\"...\",\"update\":\"...\"}],
  \"reflections\": [{\"at_step\":1,\"verdict\":\"...\",\"next_choice\":\"A\"}],
  \"deliverable\": {\"type\":\"text|file|structured\",\"content\":\"...\"},
  \"open_questions\": [],
  \"need_user_confirmation\": false,
  \"confirmation_points\": []
}
```
开始执行。""")

print("\n\n".join(parts))
PY
