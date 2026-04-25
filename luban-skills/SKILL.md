---
name: luban-skills
description: |
  面向普通用户的复杂任务执行教练 skill。把模糊、跨步骤的需求拆成可由 OpenClaw → Hermes 通过 ACP 协作完成的任务流。

  遇到以下任何情况时立即使用这个 skill：
  - 用户说"帮我完成一个复杂任务 / 拆解这个任务 / 分步骤做这件事"
  - 用户给的需求模糊但目标真实（写邮件、做方案、整理资料、规划项目）
  - 任务步骤多、材料杂、约束多，OpenClaw 容易中途跑偏
  - 需要"先做最小版本，再扩展"的稳妥推进方式
  - 需要 OpenClaw 沟通编排 + Hermes 分析执行 + ACP 协同传递的分工
  - 任务交付物不是"解释"，而是真正可用的产物（文档、清单、脚本、邮件、表格结论）
version: 1.3.0
---

# 鲁班 Skills — 普通人复杂任务执行教练

> 取名自木工祖师鲁班：**先量再锯，先做榫卯再拼合**。造的是能直接用的器物，不是炫技的模型。
> 对应本 skill 的核心方法论 —— 先明确交付物，先最小闭环，再逐步扩展。
>
> 荣誉：企鹅线下虾友线下赛第一名。

## 快速定位

本 skill 解决一个核心问题：**让普通用户一句话提需求，系统能稳妥拆解、推进、交付。**

两类用法：

- **A. 接到模糊需求** → 走 [六步工作流](#六步工作流)
- **B. 调度 Hermes 执行子任务** → 走 [Hermes 三阶段执行心法](#hermes-三阶段执行心法)

---

## 文件地图

```
luban-skills/
├── SKILL.md                              ← 你在这里
├── _meta.json
├── QUICKSTART.md                         ← 最快上手 demo
├── references/
│   ├── task-card-template.md             ← 任务卡模板
│   ├── delivery-templates.md             ← 4 类常见任务交付模板
│   ├── hermes-three-phase-prompt.md      ← Hermes Intent/ReAct/Reflect prompt
│   ├── user-facing-language.md           ← 对普通用户的表达方式
│   ├── safety-boundary.md                ← 边界与审批规则
│   ├── acp-long-task-checklist.md        ← ACP 长任务规避清单（防超时与死循环）
│   ├── complex-multiframe-comic-direct-interactive-template.md ← 多图漫画/连环图稳态场景规范
│   ├── complex-multiframe-comic-task-prompt-template.md ← 多图漫画任务 Prompt 模板
│   ├── task-card-commute-feishu-openclaw-comic-stable.md ← 通勤飞书漫画稳态任务卡示例
│   ├── feishu-notification.md            ← 飞书 webhook 通知规范（11 类 ACP 事件）
│   └── llm-behavior-rules.md             ← LLM 行为四原则
├── scripts/
│   ├── doctor.sh                         ← 一键自检
│   ├── classify_task.sh                  ← 任务类型识别 demo
│   ├── notify_feishu.sh                  ← 飞书 webhook 通知（11 类 ACP 事件）
│   ├── run_min_demo.sh                   ← 最小闭环验证
│   ├── build_prompt.sh                   ← 任务卡 → Hermes prompt 拼装器
│   ├── acp_pty_driver.py                 ← PTY 驱动 ACP client（可 SIM 模式）
│   ├── guard.py                          ← 工具调用审批（allow/block 规则）
│   ├── dispatch_acp.sh                   ← 主调度器（prompt → 流事件 → 归档）
│   └── verify_run.sh                     ← 分层验收（链路/事件/工具/状态/污染）
└── examples/
    ├── example-write-email.md            ← 写邮件示例
    ├── example-organize-docs.md          ← 整理资料示例
    ├── example-plan-project.md           ← 规划任务示例
    └── task-card-example.yaml            ← 任务卡 YAML（喂给 dispatch_acp.sh）
```

---

## 适用场景

优先用于以下五类任务：

| 类型 | 典型需求 | 最终交付物 |
|------|---------|-----------|
| **写作类** | 邮件 / 汇报 / 方案 / 总结 / 通知 / 文案 | 可直接复制使用的成稿 |
| **整理类** | 阅读多份材料、提炼重点、归纳纪要、整理待办 | 结构化结果 + 行动项 |
| **分析类** | 表格分析、方案对比、风险排查、归因建议 | 结论 + 依据 + 优先级 |
| **规划类** | 项目计划、多步骤工作拆解、长周期任务 | 里程碑 + 依赖 + 验收标准 |
| **执行辅助类** | 文件读取、目录检查、只读命令、脚本结果分析 | 执行进展 + 中间状态 + 下一步 |

## 不适合的场景

以下情况不要直接重度执行，应先收缩范围或要求人工确认：

- 高风险删除、覆盖、批量改写
- 涉及生产环境变更的命令执行
- 用户没有明确交付目标，只是泛泛聊天
- 事实依据不足但要求直接给出结论
- 需要突破权限、绕过审批、访问未授权资源
- 医疗、法律、金融等高风险结论型任务且缺乏可靠来源

---

## 多图成品任务特别规则（新增）

适用于：
- 连贯漫画
- 多张系列海报/插画
- 多视角效果图
- 要求“角色/场景一致 + 最终图片落盘”的任务

这类任务默认遵守以下规则：

1. **主目标必须是最终图片文件落盘**，不能把 storyboard / prompt 当作默认主交付
2. **先做单图探针**，确认后端真实可用、图像可返回、文件可落盘，再扩展到多图
3. **逐张生成、逐张落盘、逐张记录**，禁止把 6 张或多张图绑定成一次长串行，避免超时后 0 文件
4. **交付必须分级**：
   - 正式版：全部图片落盘
   - 预览版：部分图片落盘
   - 方案版：只有设定 / 分镜 / prompt
5. **方案版或预览版不得表述为正式完成**

对应参考文档：
- `references/complex-multiframe-comic-direct-interactive-template.md`
- `references/complex-multiframe-comic-task-prompt-template.md`
- `references/task-card-commute-feishu-openclaw-comic-stable.md`

---

## 核心原则

### A. 任务协同原则（面向流程）

| # | 原则 | 含义 |
|---|------|------|
| 1 | **先交付物，后技术** | 先确认"最终要给用户什么"，再决定是否调 Hermes、脚本、ACP |
| 2 | **先最小闭环，再扩大** | 先做一个最小可验证版本，确认方向再追加复杂度 |
| 3 | **先读后改，先证据后判断** | 没看清材料前不下结论，没足够证据前不执行 |
| 4 | **过程可见，节点可停** | 给阶段状态；遇高风险/歧义/证据不足时暂停收缩 |
| 5 | **用户成功高于系统成功** | 不是"链路跑通"叫完成，而是"结果可直接使用"才完成 |
| 6 | **有边界的自主执行** | 可主动拆解推进检查，但不越权、越界、越目录、越审批 |

### B. LLM 行为规范（面向执行）

> LLM 最常见的错误不是"不会做"，而是"默默假设 / 过度复杂 / 越权修改 / 没定义成功标准"。这四项不管住，再稳的 ACP 链路也会把任务做废。

| # | 原则 | 核心动作 |
|---|------|---------|
| 7 | **编码前先想清楚** | 不默默假设、不隐藏困惑、列出多种解释、必要时反驳用户方案 |
| 8 | **简洁优先** | 最少代码/结构、不做推测性设计、不给一次性代码加抽象、YAGNI |
| 9 | **精准修改** | 只碰必须碰的、不顺手重构、每行改动都能追溯到用户请求 |
| 10 | **目标驱动执行** | 先定义可验证的成功标准，再循环执行直到达成 |

完整规则、反模式、示例见 [`references/llm-behavior-rules.md`](references/llm-behavior-rules.md)。Hermes prompt 已通过 `BEHAVIOR_RULES` 段强制绑定。

---

## OpenClaw / Hermes / ACP 分工

```
用户  →  OpenClaw  →  ACP  →  Hermes  →  可交付成果
       (沟通编排)   (传递)   (分析执行)
```

| 角色 | 职责 |
|------|------|
| **OpenClaw** | 接收需求 / 识别任务类型 / 提炼目标和约束 / 维护多轮沟通 / 显示执行状态 / 在关键节点请求确认 / 通过 ACP 把子任务交给 Hermes |
| **ACP** | 任务从 OpenClaw 平稳传递到 Hermes / 保持上下文与阶段状态 / 支持中断、暂停、恢复、审批、回传 |
| **Hermes** | 对具体子任务做分析、规划、执行 / 阅读文件、检查目录、处理文本、调用工具 / 每步后自检 / 返回中间状态、风险与下一步 |

---

## 🚨 ACP 调度硬性规则（务必遵守）

> **2026-04-24 多轮事故教训**：本环境 `sessions_spawn` 派发到 hermes 的路径**不稳定**，hermes 子进程启动后会被过早 SIGTERM 导致 prompt_toolkit crash，任务无法完成。

### ✅ 唯一推荐路径：`bash dispatch_acp.sh`

**直接执行本地脚本**，绕过 `sessions_spawn`：

```bash
# 1. 先基于 examples/task-card-example.yaml 写一份任务卡
cat > /tmp/my-task.yaml <<'EOF'
task_label: <task-label>
task_type: 写作 / 整理 / 分析 / 规划 / 执行辅助
goal: <一句话说清最终交付物>
workdir: <workspace>
readable_dirs:
  - <workspace>/skills/luban-skills
writable_dirs: []
input_materials: []
constraints: [<关键约束>]
risks: []
first_action: <最小最安全的第一步>
acceptance: [<验收条件>]
time_budget_s: 1200
sentinel: false
EOF

# 2. 启动（实测会真调 hermes acp + LLM，输出真实四阶段结果）
bash <workspace>/skills/luban-skills/scripts/dispatch_acp.sh \
     start /tmp/my-task.yaml

# 3. 查看产物
ls <workspace>/skills/luban-skills/runs/
```

这条路径在 2026-04-23 晚间已完整调通（真实 ACP JSON-RPC + hermes + gpt-5.4 + 四阶段 JSON 输出），稳定可用。

---

### ❌ 不要用 `sessions_spawn(runtime="acp")`

本环境下已知问题（多次重现）：

1. 工具 schema 强制注入 18 个字段（`lightContext` / `timeoutSeconds` / `thread` / `cleanup` 等），agent 无法省略
2. 即便传 `timeoutSeconds=0`，adp-openclaw 的 `run` 模式仍会过早关闭 hermes stdin
3. Hermes 在 ACP 模式下 `cli.py` 的 prompt_toolkit signal handler 与 SIGTERM 不兼容，`raise RuntimeError('There is no current event loop in thread MainThread')`
4. Agent 永远等不到 `sessions_spawn` 的 `toolResult`，父会话卡死

**短期禁用**：直到 hermes 修复 signal handler 或 adp-openclaw 调整 ACP 关闭策略，所有 luban-skills 的 ACP 调度**一律走 `dispatch_acp.sh` 本地脚本**。

---

## 六步工作流

接到任务时，OpenClaw 默认按下面 6 步推进。

### 第 1 步 — 识别任务类型
判断属于：写作 / 整理 / 分析 / 规划 / 执行辅助 / 排障验证 中的哪一类。混合型先找主任务。

### 第 2 步 — 明确最终交付物
必须先把"结果长什么样"说清楚。例如：
- 一封可直接发送的邮件
- 一份两页 PPT 提纲
- 一份表格分析结论
- 一份项目推进清单 / 纪要 / 脚本 / 对比报告 / 待办

> 如果用户表达模糊，**优先根据上下文推断最可能的交付物**，不要停在泛泛讨论。

### 第 3 步 — 抽取约束
执行前明确：可用文件/目录、输出格式、时间范围、风格要求、是否允许脚本、哪些操作禁止、哪些节点必须确认、是否要求"先草稿/先最小/先只读"。

### 第 4 步 — 先做最小闭环
不要一上来全量执行。优先选最小动作：
- 先读 1 份材料
- 先生成 1 个提纲
- 先分析 1 个表
- 先验证 1 段输出格式
- 先跑只读命令
- 先产出小样本

> 最小闭环失败 → **先定位原因，不盲目叠加复杂度**。

### 第 5 步 — 分阶段执行
理解阶段（澄清）→ 执行阶段（最小动作推进）→ 检查阶段（校验内容/格式/边界/遗漏）→ 交付阶段（整理成最终可用结果）

### 第 6 步 — 验收并交付
回到"用户能不能直接用"。检查：
- [ ] 完成目标
- [ ] 符合格式
- [ ] 无关键信息遗漏
- [ ] 未越界
- [ ] 已明确指出是否需要用户确认下一步
- [ ] 可直接复制 / 发送 / 提交 / 流转

---

## Hermes 三阶段执行心法

通过 ACP 调度 Hermes 时使用此模型。完整 prompt 见 `references/hermes-three-phase-prompt.md`。

### Phase 1 — Intent（动手前先想清楚 4 件事）
- **目标**：最终要交付什么
- **约束**：可读写范围 / 风格 / 格式 / 禁止项
- **风险**：哪里容易跑偏、误判、越界
- **第一动作**：最小、最安全、最能验证方向的动作

### Phase 2 — ReAct（每一步循环）
**Reason**（为什么） → **Act**（最小动作） → **Observe**（看结果） → **Update**（更新计划）

规则：
- 不做无证据的大跳跃
- 每一步都要比上一步更接近交付物
- 每一步后判断是否已经足够停止

### Phase 3 — Reflect（每个关键节点快速复盘）
- 结果是否符合预期
- 是否被旧上下文带偏
- 是否需要缩小范围 / 回退
- 是否已满足验收标准
- 是否应该停下来向用户确认

---

## 任务卡模板（OpenClaw 内部使用）

接到复杂任务后，先在内部填好这张卡（详见 `references/task-card-template.md`）：

```
任务名称：
任务类型：写作 / 整理 / 分析 / 规划 / 执行辅助
最终交付物：
输入材料：
关键约束：
风险点：
最小闭环动作：
是否需要 Hermes：是 / 否
是否需要人工确认：是 / 否（哪些节点）
验收标准：
```

---

## 对普通用户的表达方式

无论底层是否调用 ACP / Hermes，**对用户的表达必须自然，避免堆技术词**。详见 `references/user-facing-language.md`。

✅ 应该这样说：
- "我先帮你拆成 3 步。"
- "我先做一个最小版本给你确认方向。"
- "我先读你这份材料，再给你提炼重点。"
- "这里有风险，我先停在这一步，给你两个选择。"

❌ 不要这样说：
- "现在我要做链路层验证。"
- "我准备注入哨兵并切换 workdir。"
- "我即将进入工具级调度循环。"

底层可以很技术，但面向用户的语言始终围绕：**目标、步骤、结果、风险、确认点。**

---

## ACP 长任务规避（强制）

> **2026-04-23 事故教训**：ACP persistent 任务因多步操作（GitHub 抓取 + 多轮 LLM + 脚本）连续超过 600s 超时，thread binding 把用户消息反复路由到 error 会话，形成死循环，单用户聊天瘫痪。

任何"看起来可能跑超 5 分钟"的任务，**必须**先过一遍 [`references/acp-long-task-checklist.md`](references/acp-long-task-checklist.md)，并满足：

1. **预估时长** — 含网络 I/O、外部脚本、≥3 轮 LLM、等外部回应中任意一项 → 按"长任务"处理
2. **分段执行** — 拆成多个独立可重试的 ephemeral 子任务，不要塞进单个 persistent 会话
3. **设置 TIME_BUDGET** — ≤ ACP 全局超时 × 80%，prompt 中明确告知 Hermes
4. **进度回报** — 每完成一个 ReAct 子步骤回传进度事件
5. **Checkpoint 落盘** — 每个中间产物持久化，失败后只重跑未完成段
6. **重试上限** — `max_attempts: 3`，退避 `[60s, 300s, 900s]`，耗尽后**自动解除 thread binding** 并告知用户
7. **persistent 会话健康检查** — 使用前先看会话状态；连续 ≥2 次超时立即 quarantine

**任何一项不满足，不要启动任务。** 详见 [`references/acp-long-task-checklist.md`](references/acp-long-task-checklist.md) 第六节自查清单。

---

## 飞书 Webhook 通知（强制）

OpenClaw 通过 ACP 调度 Hermes 时，**11 类关键事件必须推送飞书 webhook**，让你随时清楚后台走了哪些流程：

| 类别 | 事件 | 由谁推送 |
|------|------|---------|
| 任务生命周期 | `start` / `done` / `blocked` | OpenClaw |
| 执行进度 | `progress` / `checkpoint` / `reflect` | Hermes |
| 用户交互 | `need_confirm` | Hermes / OpenClaw |
| 异常处理 | `retry` / `timeout` / `quarantine` / `error` | OpenClaw |

统一调用 [`scripts/notify_feishu.sh`](scripts/notify_feishu.sh)，webhook URL 可从环境变量或本地 `.env` 加载；`diting-skills/.env` 仅作为可选协作 skill 的本地兼容路径。

冒烟测试：
```bash
bash scripts/notify_feishu.sh start "smoke-test" goal="验证 webhook" budget="0s"
```

完整事件规范、卡片样式、限流策略、与 OpenClaw/Hermes 的对接代码见 [`references/feishu-notification.md`](references/feishu-notification.md)。

---

## 自主 ACP 调度（不依赖其他 skill）

luban 自带完整执行层，`scripts/` 下 5 个脚本自成闭环，**不依赖 diting-skills 或任何外部 skill**：

| 脚本 | 职责 |
|------|------|
| `build_prompt.sh` | 任务卡 YAML → 完整 Hermes prompt（STRICT MODE 哨兵 + TIME_BUDGET + BEHAVIOR_RULES + NOTIFY_HOOK + OUTPUT SCHEMA） |
| `acp_pty_driver.py` | PTY 启动 `openclaw acp`；找不到 client 时自动进 **SIM 模式**模拟三阶段输出，方便离线验证链路 |
| `guard.py` | 工具调用 allow/block 规则匹配；默认白名单见 `references/allowlist-default.yaml`，可用 `GUARD_RULES_PATH` 覆盖 |
| `dispatch_acp.sh` | 主调度器：拼 prompt → 启动 driver → 实时监听 stdout → 事件分流 → guard 判定 → 飞书通知 → 归档 |
| `verify_run.sh` | 分层验收：链路/事件/工具/状态/污染 5 层，`--strict` 模式要求 status=done |

### 最短用法

```bash
# 准备任务卡（参考 examples/task-card-example.yaml）
vim my-task.yaml

# 启动（真实 openclaw 存在时真调，不存在时进 SIM 模式）
bash scripts/dispatch_acp.sh start my-task.yaml

# 验收
bash scripts/verify_run.sh <session_id> --strict

# 产物归档在 runs/<session_id>/
#   prompt.txt      最终下发给 Hermes 的 prompt
#   stdout.log      ACP client 的完整 stdout
#   events.jsonl    分流后的事件流（thinking/tool_call/tool_blocked/event_progress/...）
#   state.json      会话状态快照
#   client.pid      进程 PID（stop 命令用）
```

### DRY_RUN 模式

```bash
DRY_RUN=true bash scripts/dispatch_acp.sh start my-task.yaml
# → 只拼 prompt 并打印，不启动 client，不发通知
```

### 设计对齐

- **长任务防护**：`time_budget_s` 通过 prompt 的 TIME_BUDGET 段注入 Hermes；driver 自身也用 `ACP_TIMEOUT_S` 硬超时兜底
- **通知联动**：11 类事件（见 `references/feishu-notification.md`）在 dispatch 里真调 `notify_feishu.sh`
- **行为约束**：`BEHAVIOR_RULES` 由 `build_prompt.sh` 自动嵌入每次 prompt，不靠人记
- **污染防护**：STRICT MODE 哨兵 + 可读目录白名单由任务卡驱动生成，覆盖 `safety-boundary.md` 的已知坑 #4

---

## 调度 Hermes 的判定

只有以下情况才优先调度 Hermes：
- 需要读取、比较、总结较多文件
- 需要多步骤推理
- 需要执行受控的工具操作
- 需要把复杂任务拆成多个动作
- 需要中间状态回传
- 需要在边界内自主推进

简单回答 / 轻量改写 / 单轮说明 → **不必强行调度 Hermes**。

---

## 安全与边界（详见 `references/safety-boundary.md`）

### 目录边界
- 只能在明确授权的目录和文件范围内工作
- 不因"看起来相关"就越目录读取
- 不引用不在本任务范围内的旧文件、旧任务、旧工件

### 行为边界
- 默认先只读，再考虑修改
- 默认先草稿，再考虑正式执行
- 涉及覆盖、删除、批量变更、系统配置修改时必须提高警惕

### 审批节点
以下情况优先请求人工确认：
- 破坏性操作
- 影响生产环境
- 涉及敏感数据
- 输出将被直接对外发送
- 后果不可逆

---

## 失败时的正确处理

不要假装完成，也不要重复无效尝试：

1. 明确失败发生在哪一步
2. 说明已知原因
3. 说明未知部分
4. 给出最小修复建议
5. 从最近的稳定点重新开始

输出范式：
- "我已经确认哪一步是通的"
- "目前卡在什么地方"
- "最可能的原因是什么"
- "下一步该怎么缩小范围"

---

## 成功标准

只有同时满足以下条件，才算任务真正完成：

1. 输出与用户目标一致
2. 结果格式正确
3. 关键约束未违反
4. 没有明显遗漏
5. 用户可以直接使用或继续流转
6. 如需确认，已明确指出确认点
7. 没有把内部技术日志误当成交付物

---

## 深入参考

| 需要了解 | 去读 |
|---------|------|
| 任务卡完整字段与示例 | `references/task-card-template.md` |
| 写作 / 整理 / 分析 / 规划 4 类交付模板 | `references/delivery-templates.md` |
| Hermes Intent/ReAct/Reflect 完整 prompt | `references/hermes-three-phase-prompt.md` |
| 对普通用户的表达句式库 | `references/user-facing-language.md` |
| 边界规则与审批清单 | `references/safety-boundary.md` |
| ACP 长任务防超时 / 防死循环清单 | `references/acp-long-task-checklist.md` |
| 飞书 webhook 通知规范（11 类 ACP 事件） | `references/feishu-notification.md` |
| LLM 行为规范（四原则 + 反模式） | `references/llm-behavior-rules.md` |
| 写邮件 / 整理资料 / 规划项目 完整示例 | `examples/` |

---

## 一句话总结

**让普通用户一句话提需求，系统就能拆解任务、稳妥推进、必要时确认，最后交付真正可用的结果。**
