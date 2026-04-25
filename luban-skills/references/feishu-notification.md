# 飞书 Webhook 通知规范

> **目的**：让你（用户）在飞书里实时看到 OpenClaw 通过 ACP 调度 Hermes 走了哪些流程。任何 ACP 关键事件都必须推送，不要让你"不知道后台在干什么"。

---

## 一、什么时候必须推送

**11 类事件，全部强制推送**：

| 事件 | 触发时机 | 颜色 | 给你看什么 |
|------|---------|------|-----------|
| `start` | OpenClaw 把任务交给 ACP 那一刻 | 蓝 | 任务标签 / 目标 / 时间预算 / 是否 persistent |
| `progress` | Hermes 每完成一个 ReAct 子步骤 | 灰 | step N/M / elapsed / 上一动作 |
| `checkpoint` | 中间产物落盘到 `workspace/checkpoints/` | 青 | 段号 / 文件路径 / 大小 |
| `reflect` | Hermes 进入 Phase 3 Reflect | 紫 | 当前距验收差什么 / 选择了 A/B/C/D |
| `need_confirm` | Hermes 回传 `status: need_confirmation` | 黄 | 待确认点 / OpenClaw 给你的话术预览 |
| `retry` | OpenClaw 触发第 N 次重试 | 橙 | attempt N/3 / 退避 / 上次失败原因 |
| `timeout` | 单次执行超时 | 橙 | elapsed / budget / 已到第几次 |
| `quarantine` | 连续 ≥2 次超时，会话被隔离 + thread binding 解绑 | 红 | 会话 ID / 解绑的用户/线程 |
| `done` | 任务完成 | 绿 | 总耗时 / 交付物路径 / 是否需用户确认 |
| `blocked` | 任务卡住，max_attempts 耗尽 | 红 | 失败链 / 给你的两个备选 |
| `error` | 异常退出（非超时） | 红 | 错误摘要 / 最近一次 ReAct 步骤 |

---

## 二、调用方式

**所有事件统一通过 `scripts/notify_feishu.sh` 发送，OpenClaw / Hermes 都用同一个脚本。**

```bash
notify_feishu.sh <event> <task_label> [k=v ...]
```

**完整示例**：

```bash
# 任务启动
notify_feishu.sh start "github-analyze" \
  goal="拉 awesome-gpt-image-2-prompts 并生成报告" \
  budget="1200s" \
  mode="ephemeral" \
  user="6334207305"

# 进度（每个 ReAct 步骤后）
notify_feishu.sh progress "github-analyze" \
  step="3/8" \
  elapsed="120s" \
  last="拉取 README 完成，1.2KB"

# Checkpoint（中间产物落盘）
notify_feishu.sh checkpoint "github-analyze" \
  segment="2" \
  file="workspace/checkpoints/02-analysis.md" \
  size="14KB"

# Reflect 节点
notify_feishu.sh reflect "github-analyze" \
  verdict="部分符合预期" \
  choice="B-收缩范围" \
  reason="源码体积过大，改为只读 README + package.json"

# 需要用户确认
notify_feishu.sh need_confirm "github-analyze" \
  question="是否对外发送报告到飞书群?" \
  preview="报告共 1.2K 字，包含 5 个章节..."

# 单次超时
notify_feishu.sh timeout "github-analyze" \
  attempt="2/3" \
  elapsed_s="600" \
  budget_s="1200"

# 触发重试
notify_feishu.sh retry "github-analyze" \
  attempt="3/3" \
  backoff="900s" \
  last_error="网络超时 EAI_AGAIN"

# 会话隔离
notify_feishu.sh quarantine "github-analyze" \
  session_id="52dc3fdb-0697-4592-8772-ffe5c45aea74" \
  unbound_user="6334207305" \
  reason="连续 2 次超时"

# 任务完成
notify_feishu.sh done "github-analyze" \
  total_time="18m32s" \
  deliverable="workspace/checkpoints/03-report.md" \
  need_user_confirm="是"

# 任务卡住
notify_feishu.sh blocked "github-analyze" \
  failed_chain="2 次超时 + 1 次 GitHub 限流" \
  options="A-缩小范围只读 README / B-给我代码副本"

# 异常
notify_feishu.sh error "github-analyze" \
  step="5/8" \
  message="permission denied: workspace/x.json"
```

---

## 三、配置

### Webhook URL 来源（按优先级）

1. 环境变量 `FEISHU_WEBHOOK_URL`（最高）
2. `luban-skills/.env`
3. `diting-skills/.env`（可选协作 skill 的本地配置）
4. `~/.openclaw/.env`

如果都没有，脚本立即报错退出码 2，不会静默吞掉。

开源仓库只应保留变量名和假 URL 示例。不要提交真实 webhook、`.env`、token 或任何私有配置。

### 静默 / 调试

```bash
# 临时静默（不推送）
FEISHU_WEBHOOK_URL="" notify_feishu.sh start "test"   # 报错退出，等同于禁用

# 调试看 payload
FEISHU_WEBHOOK_URL="https://example.com/dryrun" \
  notify_feishu.sh start "test" goal="x"
```

### 失败行为

- 推送失败（HTTP 非 200，或网络超时 5s）**不阻塞**主流程
- 失败信息打到 stderr，主流程继续
- 因为通知本身不能成为任务失败的原因

---

## 四、与 OpenClaw / Hermes 的对接

### OpenClaw 侧（任务编排器）

**必发事件**：`start` / `retry` / `quarantine` / `done` / `blocked`

```bash
# 启动任务前
notify_feishu.sh start "$LABEL" goal="$GOAL" budget="${TIMEOUT}s" mode="$MODE"

# 调度 Hermes
acp_dispatch ...

# 根据 Hermes 回传决定下一步
case "$STATUS" in
  done)         notify_feishu.sh done "$LABEL" total_time="$T" deliverable="$F" ;;
  blocked)      notify_feishu.sh blocked "$LABEL" failed_chain="$REASON" options="$OPTS" ;;
  need_confirm) notify_feishu.sh need_confirm "$LABEL" question="$Q" ;;
  timeout)
    notify_feishu.sh timeout "$LABEL" attempt="$N/3" elapsed_s="$E"
    if [ "$N" -lt 3 ]; then
      notify_feishu.sh retry "$LABEL" attempt="$((N+1))/3" backoff="${BACKOFF}s"
    else
      notify_feishu.sh quarantine "$LABEL" session_id="$SID" reason="3 次重试耗尽"
    fi
    ;;
esac
```

### Hermes 侧（执行体）

**必发事件**：`progress`（每步） / `checkpoint`（每段产物） / `reflect`（每个 Reflect 节点） / `error`

把 `notify_feishu.sh` 注入到 Hermes 的 prompt 工具集里，让 Hermes 在每个 ReAct 步骤的 Update 阶段后调用一次。

在 prompt 模板里加这一段（已加入 `hermes-three-phase-prompt.md`，见下文）：

```
NOTIFY_HOOK: 每完成一个 ReAct 步骤，调用：
  bash scripts/notify_feishu.sh progress "<task_label>" step="N/M" elapsed="Xs" last="..."
每个 Reflect 节点结束，调用：
  bash scripts/notify_feishu.sh reflect "<task_label>" verdict="..." choice="..."
每个 checkpoint 写盘后，调用：
  bash scripts/notify_feishu.sh checkpoint "<task_label>" segment="N" file="..." size="..."
```

---

## 五、推送量控制（避免飞书消息轰炸）

| 类型 | 频次 | 限流策略 |
|------|------|---------|
| start / done / blocked / quarantine / error | 一次任务一次 | 不限流 |
| need_confirm / reflect | 关键节点 | 不限流 |
| retry / timeout | 受 max_attempts=3 限制 | 不限流 |
| **progress** | 每步一次 | **如果一个任务步骤 > 20，只推送 1/5/10/15/20 这种关键节点** |
| **checkpoint** | 每段一次 | 不限流（段数本来就少） |

如果某类事件高频出现到刷屏，先回头看是不是任务拆得不够细 — 这是任务设计问题，不是通知问题。

---

## 六、卡片样式预览

飞书 interactive 卡片，按事件类型上色：

```
🚀 ACP 任务启动 — github-analyze            （蓝色 header）
─────────────────────────────────────────
goal: 拉 awesome-gpt-image-2-prompts 并生成报告
budget: 1200s
mode: ephemeral
user: 6334207305
─────────────────────────────────────────
host: openclaw-prod · 2026-04-23 18:32:01 CST
```

```
✅ ACP 任务完成 — github-analyze            （绿色 header）
─────────────────────────────────────────
total_time: 18m32s
deliverable: workspace/checkpoints/03-report.md
need_user_confirm: 是
─────────────────────────────────────────
host: openclaw-prod · 2026-04-23 18:50:33 CST
```

```
🚧 ACP 会话已隔离 — github-analyze          （红色 header）
─────────────────────────────────────────
session_id: 52dc3fdb-0697-4592-8772-ffe5c45aea74
unbound_user: 6334207305
reason: 连续 2 次超时
─────────────────────────────────────────
host: openclaw-prod · 2026-04-23 19:02:11 CST
```

---

## 七、自查

调试通知是否已接通：

```bash
# 1. 直接发一条测试卡片
bash scripts/notify_feishu.sh start "smoke-test" goal="验证 webhook" budget="0s"

# 飞书群应当立即收到一张蓝色 header 卡片，标题是
# "🚀 ACP 任务启动 — smoke-test"
```

收不到时按这个顺序查：
1. `FEISHU_WEBHOOK_URL` 是否在 env 里（脚本会从 4 个位置依次找）
2. 网络出口是否能访问 `open.feishu.cn`
3. 飞书机器人是否被踢出群、被禁用
4. 看 stderr 输出的 HTTP code 和飞书返回的 JSON 错误
