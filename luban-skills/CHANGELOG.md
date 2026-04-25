# CHANGELOG

## 1.3.0 - 2026-04-25

### Added
- 多图成品任务稳态规则：正式版 / 预览版 / 方案版分级。
- 首图探针 → 逐张生成 → 后台回收 → 文件级验收流程。
- 复杂漫画 / 系列插画 / 多视角效果图任务入口文档。
- 通勤飞书指挥 OpenClaw 生图任务 6 张正式版验证案例。

### Changed
- ACP 调度推荐路径固化为本地 `dispatch_acp.sh`。
- 多图任务不再把 storyboard / prompt 作为默认主交付。
- ACP 主会话返回 partial 时，必须继续检查后台进程与输出目录。

### Fixed
- 避免一次性批量生成导致超时后 0 图落盘。
- 避免 ACP/Hermes 主会话结束后误判后台生图任务失败或完成。

## 1.2.0 - 2026-04-24

### Added
- luban-skills + ACP Hermes + checkpoint 验收工作流。
- 复杂任务通过 checkpoint 续作和验收的公共流程。

### Changed
- 默认不使用不稳定的 `sessions_spawn(runtime="acp")` 路径处理 luban 任务。

## 1.1.0 - 2026-04-23

### Fixed
- 修复 ACP 调度从 SIM / 错误 stdin 模式退化的问题。
- `acp_pty_driver.py` 改为真实 ACP JSON-RPC 客户端链路。

## 1.0.0 - 2026-04-23

### Added
- 初始鲁班复杂任务执行教练能力。
- 任务卡、六步工作流、Hermes 三阶段 prompt、通知与自检脚本。
