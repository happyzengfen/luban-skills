# 鲁班 Skills（luban-skills）

> 普通人复杂任务执行教练：把一句模糊需求，变成可执行、可追踪、可验收的交付流程。

**当前版本：v1.3.0**
**定位：OpenClaw + ACP + Hermes 协同任务流 Skill**
**中文描述：面向普通用户的复杂任务执行教练，把一句模糊需求变成可执行、可追踪、可验收的交付流程。**
**荣誉：企鹅线下虾友线下赛第一名。**
**核心理念：先交付物，后技术；先最小闭环，再扩大范围。**

---

## 1. 这个 Skill 是做什么的？

`luban-skills` 用来处理那些“不是一句话能回答完”的复杂任务。

它不是单纯写 Prompt 的工具，而是一套完整的任务执行协议：

```text
用户需求
  ↓
OpenClaw 理解目标与约束
  ↓
luban-skills 生成任务卡和执行规则
  ↓
通过 ACP 调度 Hermes 执行
  ↓
产出文件 / 文档 / 图片 / 报告
  ↓
按验收标准检查交付物
```

一句话：**它让 AI 不只是给建议，而是真正按流程完成产物。**

---

## 2. 适合什么场景？

| 场景 | 示例 | 最终交付物 |
|---|---|---|
| 写作类 | 邮件、公众号文章、汇报、通知、方案 | 可直接使用的成稿 |
| 整理类 | 会议纪要、资料提炼、待办归纳 | 结构化清单 / 行动项 |
| 分析类 | 表格分析、竞品分析、方案对比 | 结论 + 依据 + 优先级 |
| 规划类 | 项目计划、活动方案、执行拆解 | 里程碑 + 任务卡 |
| 执行辅助类 | 读取文件、检查目录、脚本结果分析 | 状态报告 + 下一步 |
| 多图成品类 | 连贯漫画、产品海报、系列插画、多视角效果图 | 实际图片文件 + 交付报告 |

---

## 3. 不适合什么场景？

以下任务不要直接重度执行，应先收缩范围或人工确认：

- 删除、覆盖、批量改写等高风险操作
- 生产环境变更
- 没有明确交付目标的闲聊
- 事实依据不足却要求强结论
- 医疗、法律、金融等高风险判断
- 需要绕过权限、审批或安全边界的任务

---

## 4. 核心原则

| 原则 | 说明 |
|---|---|
| 先交付物，后技术 | 先确认最终要交付什么，再决定怎么做 |
| 先最小闭环，再扩大 | 先跑一个能验收的小版本，再扩展复杂度 |
| 先读后改，先证据后判断 | 没看清材料前不下结论，不盲目执行 |
| 过程可见，节点可停 | 关键步骤有状态，遇到风险可以暂停 |
| 用户成功高于系统成功 | 链路跑通不等于任务完成，用户能用才算完成 |
| 有边界的自主执行 | 主动推进，但不越权、不越目录、不绕审批 |

---

## 5. 标准工作流

### Step 1：识别任务类型
判断用户要的是写作、整理、分析、规划、执行辅助，还是多图成品。

### Step 2：定义最终交付物
明确“完成后要给用户什么”：文件、图片、文章、表格、报告、清单等。

### Step 3：生成任务卡
使用 `references/task-card-template.md` 或 examples 中的 YAML 模板写清楚：

- 任务名称
- 任务类型
- 最终目标
- 工作目录
- 可读目录
- 可写目录
- 输入材料
- 约束条件
- 风险点
- 第一行动
- 验收标准
- 时间预算

### Step 4：调度 ACP Hermes
推荐使用本地调度脚本：

```bash
bash scripts/dispatch_acp.sh start /path/to/task-card.yaml
```

> 注意：当前稳定路径是 `dispatch_acp.sh`。不要优先使用不稳定的 `sessions_spawn(runtime="acp")` 路径。

### Step 5：执行与产物落盘
Hermes 按任务卡执行，产出文件、报告、图片或其他交付物。

### Step 6：验收与汇报
对照 acceptance 标准检查：

- 文件是否存在
- 格式是否正确
- 内容是否符合目标
- 是否有失败项
- 是否需要降级为预览版 / 方案版

---

## 6. 多图成品任务规则（v1.3.0 重点）

适用于：

- 连贯漫画
- 系列海报
- 产品宣传图
- 多视角效果图
- 角色一致的系列插画

默认规则：

1. **最终图片文件落盘才算正式完成**
2. **先做第 1 张探针图**，确认图片后端可用
3. **探针成功后逐张生成**，不要一次性全量绑定
4. **每张图独立落盘、独立记录**
5. **只有全部图片成功落盘，才叫正式版**
6. 部分成功只能叫预览版
7. 只有设定 / 分镜 / Prompt 只能叫方案版

交付分级：

| 等级 | 含义 |
|---|---|
| 正式版 | 全部目标图片真实落盘 |
| 预览版 | 部分图片已落盘 |
| 方案版 | 只有设定、分镜、Prompt，未完成成图 |

---

## 7. 目录结构

```text
luban-skills/
├── SKILL.md                              # Skill 主说明与执行规则
├── README.md                             # 分享版说明文档
├── QUICKSTART.md                         # 快速上手
├── CHANGELOG.md                          # 版本记录
├── _meta.json                            # Skill 元信息
├── examples/                             # 示例任务
│   ├── example-write-email.md
│   ├── example-organize-docs.md
│   ├── example-plan-project.md
│   └── task-card-example.yaml
├── references/                           # 参考模板与规范
│   ├── task-card-template.md
│   ├── delivery-templates.md
│   ├── hermes-three-phase-prompt.md
│   ├── user-facing-language.md
│   ├── safety-boundary.md
│   ├── acp-long-task-checklist.md
│   ├── complex-multiframe-comic-direct-interactive-template.md
│   ├── complex-multiframe-comic-task-prompt-template.md
│   ├── task-card-commute-feishu-openclaw-comic-stable.md
│   ├── feishu-notification.md
│   └── llm-behavior-rules.md
├── scripts/                              # 执行脚本
│   ├── doctor.sh
│   ├── classify_task.sh
│   ├── run_min_demo.sh
│   ├── build_prompt.sh
│   ├── dispatch_acp.sh
│   ├── acp_pty_driver.py
│   ├── guard.py
│   ├── notify_feishu.sh
│   └── verify_run.sh
└── tests/                                # 基础测试
    └── test_dispatch_guard_classification.py
```

---

## 8. 快速开始

### 8.1 自检

```bash
cd luban-skills
bash scripts/doctor.sh
```

### 8.2 任务类型识别 Demo

```bash
bash scripts/classify_task.sh "帮我根据这份资料写一封沟通邮件"
```

预期输出类似：

```text
TASK_TYPE=写作类
DELIVERABLE=可直接发送的邮件
MIN_LOOP=先提炼 3 个要点 → 出一版简洁初稿
LUBAN_SKILLS_DEMO_DONE
```

### 8.3 使用任务卡执行

先复制示例任务卡：

```bash
cp examples/task-card-example.yaml /tmp/my-task.yaml
```

编辑 `/tmp/my-task.yaml` 后执行：

```bash
bash scripts/dispatch_acp.sh start /tmp/my-task.yaml
```

执行记录会写入：

```text
runs/<session-id>/
```

---

## 9. 任务卡最小示例

```yaml
task_label: demo-write-email
task_type: 写作类
goal: 根据会议纪要生成一封 200 字内的项目推进邮件
workdir: <workspace>
readable_dirs:
  - <workspace>
writable_dirs: []
input_materials:
  - <workspace>/meeting-notes.md
constraints:
  - 语气正式
  - 不超过 200 字
  - 分三段以内
risks:
  - 会议纪要可能信息不完整
first_action: 先读取会议纪要，提炼3个关键点
acceptance:
  - 生成一封可直接复制发送的邮件
  - 包含背景、当前进展、下一步动作
time_budget_s: 600
sentinel: false
```

---

## 10. 典型使用口令

用户可以这样触发：

- “用 luban-skills 帮我拆解这个任务”
- “用 ACP Hermes 执行，并保留 checkpoint”
- “帮我生成一组产品宣传图，最后要真实落盘”
- “先做一个最小版本，再扩展正式版”
- “不要只给方案，要有产物和验收”

---

## 11. 版本记录

### v1.3.0 - 2026-04-25

新增重点：

- 多图成品任务稳态规则
- 首图探针
- 逐张生成
- 后台回收
- 文件级验收
- 正式版 / 预览版 / 方案版分级
- 6 张漫画正式版验证案例

### v1.2.0 - 2026-04-24

- 增加 luban-skills + ACP Hermes + checkpoint 验收工作流
- 默认不使用不稳定的 `sessions_spawn(runtime="acp")` 路径

### v1.1.0 - 2026-04-23

- 修复 ACP 调度从 SIM / 错误 stdin 模式退化的问题
- `acp_pty_driver.py` 改为真实 ACP JSON-RPC 客户端链路

### v1.0.0 - 2026-04-23

- 初始鲁班复杂任务执行教练能力
- 任务卡、六步工作流、Hermes 三阶段 Prompt、通知与自检脚本

---

## 12. 分享说明

分享这个技能包时，建议只包含：

- `SKILL.md`
- `README.md`
- `QUICKSTART.md`
- `CHANGELOG.md`
- `_meta.json`
- `examples/`
- `references/`
- `scripts/`
- `tests/`

不建议分享：

- `.env`
- `runs/`
- `tmp/`
- `checkpoints/`
- `.pytest_cache/`
- `__pycache__/`
- `.DS_Store`
- `*.bak*`

---

## 13. 一句话介绍

**鲁班 Skills 是一套让 AI 从“会说方案”升级为“能按任务卡执行、通过 ACP Hermes 协作、最终交付可验收产物”的复杂任务执行协议。**
