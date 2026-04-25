# 鲁班 Skills Quickstart

## 目标
最快理解这个 skill 怎么用：接到一个模糊需求，按 6 步把它变成可交付结果。

## 1. 先跑 doctor 自检
```bash
bash scripts/doctor.sh
```
检查：SKILL.md / _meta.json / references / examples 是否完整。

## 2. 跑最小 demo（任务类型识别）
```bash
bash scripts/classify_task.sh "帮我根据这份资料写一封沟通邮件"
```
预期输出：
```
TASK_TYPE=写作类
DELIVERABLE=可直接发送的邮件
MIN_LOOP=先提炼 3 个要点 → 出一版简洁初稿
LUBAN_SKILLS_DEMO_DONE
```

## 3. 真实使用方式（OpenClaw 接到用户请求时）

### Step A — 填任务卡（`references/task-card-template.md`）
```
任务名称：给张总写项目推进邮件
任务类型：写作类
最终交付物：一封 200 字内可直接发送的邮件
输入材料：会议纪要.md
关键约束：语气正式、不超过 3 段
最小闭环动作：先提取 3 个要点，出简洁初稿
是否需要 Hermes：是（读纪要）
验收标准：用户可直接复制发送
```

### Step B — 对用户的表达
> "我先帮你读一下会议纪要，提炼 3 个重点，然后给你一版简洁邮件初稿，你确认方向后我再做格式优化。"

**不要说**："我即将通过 ACP 调度 Hermes 读取 /path/file.md 进入 ReAct 循环。"

### Step C — 调度 Hermes（参考 `references/hermes-three-phase-prompt.md`）
把子任务以 Intent/ReAct/Reflect prompt 交给 Hermes，等待回传结构化结果。

### Step D — 验收交付
对照[成功标准](../SKILL.md#成功标准) 7 条，全部满足才算完成。

### Step E — 如果是多图成品任务，走稳态规则
当任务是漫画、系列插画、多视角效果图时，不要直接整批渲染，必须额外执行：
1. 先看 `references/complex-multiframe-comic-direct-interactive-template.md`
2. 再用 `references/complex-multiframe-comic-task-prompt-template.md` 写任务 Prompt
3. 优先复用 `references/task-card-commute-feishu-openclaw-comic-stable.md` 的结构
4. 先做第 1 张探针图，成功后再逐张生成其余图片

## 4. 如果失败，按这个顺序查
1. 交付物是否明确？模糊 → 回 Step A 重新抽取
2. 最小闭环是否跑通？没跑通 → 缩小范围，不要叠加
3. 是否被旧材料 / 旧上下文带偏？→ 参考 diting-skills 的哨兵与工作区隔离
4. 用户是否真正可用结果？→ 回到 Step B 补齐格式

## 5. 核心原则
- 先交付物，后技术
- 先最小闭环，再扩大范围
- 先读后改，先证据后判断
- 过程可见，节点可停
