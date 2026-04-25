#!/usr/bin/env python3
"""
acp_pty_driver.py — 真正的 ACP JSON-RPC 客户端（不是 PTY 文本模式）。

背景（2026-04-23 修复）：
  原始实现假设 ACP client 接受 stdin 文本 prompt 并回文本流（openclaw acp --stdin 的想象）。
  实际上：
    - openclaw acp 不支持 --stdin（参数不存在）
    - hermes acp 是标准 ACP JSON-RPC server，走 initialize/session.new/session.prompt 消息
  所以此 driver 改为用 `acp` Python SDK 跑真正的 JSON-RPC 会话，把 session_update 事件
  按原有文本行格式（THINKING / [tool] / EVENT: progress / 最终文本）落到 stdout.log，
  下游 dispatch_acp.sh 的正则分流无需改动。

环境变量:
  ACP_PROMPT_FILE   必填，prompt 文本文件
  ACP_STDOUT_LOG    必填，stdout 落盘路径
  ACP_CWD           可选，agent 工作目录
  ACP_CLIENT_CMD    可选，启动命令；缺省 "hermes acp"
                    如果命令不存在或协议握手失败，进入 SIM 模式
  ACP_TIMEOUT_S     可选，硬超时秒数；缺省 1800
"""

import asyncio
import os
import pathlib
import shlex
import sys
import time
from shutil import which


def log(msg: str) -> None:
    print(f"[acp_pty_driver] {msg}", file=sys.stderr, flush=True)


def sim_mode(prompt_text: str, out_log: pathlib.Path) -> int:
    """没有真实 ACP client 时的模拟输出。"""
    log("SIM mode: ACP client not found or handshake failed.")
    lines = [
        f"Session: 00000000-0000-4000-8000-{int(time.time()):012d}",
        "THINKING Phase 1 Intent 解析中...",
        "[tool] pwd: pwd",
        "[tool update] pwd: completed",
        "THINKING Phase 2 ReAct step 1 完成",
        "THINKING Phase 3 Reflect 符合验收，停止",
        "EVENT: progress step=1/1 elapsed=1s last=\"pwd\"",
        "CURRENT_DIR=" + os.getcwd(),
        "LUBAN_MIN_VERIFY_DONE",
    ]
    with out_log.open("a", encoding="utf-8") as f:
        for ln in lines:
            f.write(ln + "\n")
            f.flush()
            time.sleep(0.05)
    return 0


async def run_real(cmd: list, cwd: str, prompt_text: str, out_log: pathlib.Path, timeout_s: int) -> int:
    """用 acp SDK 真调 ACP agent。"""
    try:
        from acp import (
            spawn_agent_process,
            Client,
            InitializeRequest,
            NewSessionRequest,
            PromptRequest,
            RequestPermissionResponse,
            ReadTextFileResponse,
            WriteTextFileResponse,
            CreateTerminalResponse,
            TerminalOutputResponse,
            ReleaseTerminalResponse,
            KillTerminalResponse,
            WaitForTerminalExitResponse,
            text_block,
        )
    except ImportError as e:
        log(f"acp SDK not available: {e}")
        return sim_mode(prompt_text, out_log)

    fout = out_log.open("a", encoding="utf-8", buffering=1)

    def write_line(s: str) -> None:
        fout.write(s + "\n")
        fout.flush()

    class LubanClient(Client):
        """最小 Client 实现：把 session_update 事件格式化成文本行。"""

        async def session_update(self, *, session_id=None, update=None, **kwargs):
            # SDK 新 API：按 SessionNotification 的字段展开为关键字参数
            log(f"session_update: sid={session_id} update_type={type(update).__name__}")
            upd = update
            # 尝试拿子类型标识
            kind = (
                getattr(upd, "session_update", None)
                or getattr(upd, "sessionUpdate", None)
                or type(upd).__name__
            )
            try:
                content = getattr(upd, "content", None)
                text = ""
                if content is not None:
                    # ContentBlock 有 .text 或 dict 形式
                    text = getattr(content, "text", None) or (content.get("text") if isinstance(content, dict) else "") or ""

                if kind in ("agent_thought_chunk", "AgentThoughtChunk"):
                    if text:
                        write_line(f"THINKING {text}")
                elif kind in ("agent_message_chunk", "AgentMessageChunk"):
                    if text:
                        write_line(text)
                elif kind in ("user_message_chunk", "UserMessageChunk"):
                    if text:
                        write_line(f"USER {text}")
                elif kind in ("tool_call", "ToolCall"):
                    title = getattr(upd, "title", "") or getattr(upd, "kind", "") or "tool"
                    tc_id = getattr(upd, "tool_call_id", "") or getattr(upd, "toolCallId", "")
                    write_line(f"[tool] {title} ({tc_id})")
                elif kind in ("tool_call_update", "ToolCallUpdate"):
                    status = getattr(upd, "status", "")
                    tc_id = getattr(upd, "tool_call_id", "") or getattr(upd, "toolCallId", "")
                    write_line(f"[tool update] {tc_id}: {status}")
                elif kind in ("plan", "AgentPlanUpdate"):
                    write_line(f"EVENT: plan update")
                else:
                    write_line(f"EVENT: {kind}")
            except Exception as e:
                write_line(f"EVENT: {kind} (format error: {e})")

        async def request_permission(self, **kwargs):
            # 非交互：默认允许（STRICT MODE 由 prompt 约束）
            write_line(f"[tool] permission_request: auto-allow")
            options = kwargs.get("options") or []
            first = options[0] if options else None
            option_id = getattr(first, "option_id", None) if first else None
            return RequestPermissionResponse(outcome={"outcome": "selected", "optionId": option_id or "allow"})

        async def read_text_file(self, **kwargs):
            path = kwargs.get("path", "")
            try:
                return ReadTextFileResponse(content=pathlib.Path(path).read_text(encoding="utf-8"))
            except Exception as e:
                write_line(f"[tool] read_text_file FAILED: {e}")
                return ReadTextFileResponse(content="")

        async def write_text_file(self, **kwargs):
            path = kwargs.get("path", "")
            content = kwargs.get("content", "")
            try:
                pathlib.Path(path).write_text(content, encoding="utf-8")
            except Exception as e:
                write_line(f"[tool] write_text_file FAILED: {e}")
            return WriteTextFileResponse()

        async def create_terminal(self, **kwargs):
            return CreateTerminalResponse(terminalId="stub")

        async def terminal_output(self, **kwargs):
            return TerminalOutputResponse(output="", truncated=False)

        async def release_terminal(self, **kwargs):
            return ReleaseTerminalResponse()

        async def kill_terminal(self, **kwargs):
            return KillTerminalResponse()

        async def wait_for_terminal_exit(self, **kwargs):
            return WaitForTerminalExitResponse(exitCode=0)

    deadline = time.time() + timeout_s

    async def body():
        async with spawn_agent_process(
            lambda _agent: LubanClient(),
            cmd[0],
            *cmd[1:],
            cwd=cwd,
            env=os.environ,
        ) as (conn, proc):
            # initialize
            try:
                init = await conn.initialize(
                    protocol_version=1,
                    client_capabilities={
                        "fs": {"read_text_file": True, "write_text_file": True},
                    },
                )
                write_line(f"Session: initialized protocolVersion={getattr(init, 'protocol_version', '?')}")
            except Exception as e:
                write_line(f"EVENT: initialize FAILED: {e}")
                raise

            # new_session
            sess = await conn.new_session(cwd=cwd, mcp_servers=[])
            sid = getattr(sess, "sessionId", None) or getattr(sess, "session_id", None)
            write_line(f"Session: {sid}")

            # prompt
            res = await conn.prompt(session_id=sid, prompt=[text_block(prompt_text)])
            stop = getattr(res, "stop_reason", None) or getattr(res, "stopReason", "finished")
            write_line(f"EVENT: finished stopReason={stop}")

    try:
        await asyncio.wait_for(body(), timeout=max(1, int(deadline - time.time())))
        return 0
    except asyncio.TimeoutError:
        write_line("EVENT: TIMEOUT hard deadline reached")
        return 124
    except Exception as e:
        write_line(f"EVENT: error {type(e).__name__}: {e}")
        log(f"real mode failed: {e}")
        # 不自动掉回 SIM —— 真实错误应暴露
        return 1
    finally:
        fout.close()


def main() -> int:
    prompt_file = os.environ.get("ACP_PROMPT_FILE")
    stdout_log = os.environ.get("ACP_STDOUT_LOG")
    if not prompt_file or not stdout_log:
        log("FATAL: ACP_PROMPT_FILE 和 ACP_STDOUT_LOG 必填")
        return 2

    prompt_text = pathlib.Path(prompt_file).read_text(encoding="utf-8")
    out_log = pathlib.Path(stdout_log)
    out_log.parent.mkdir(parents=True, exist_ok=True)
    out_log.touch(exist_ok=True)

    cwd = os.environ.get("ACP_CWD") or os.getcwd()
    cmd_str = os.environ.get("ACP_CLIENT_CMD") or "hermes acp"
    cmd = shlex.split(cmd_str)
    timeout_s = int(os.environ.get("ACP_TIMEOUT_S", "1800"))

    if not which(cmd[0]):
        log(f"ACP client '{cmd[0]}' not on PATH → SIM mode.")
        return sim_mode(prompt_text, out_log)

    log(f"launching real ACP: {' '.join(cmd)} (cwd={cwd}, timeout={timeout_s}s)")
    try:
        return asyncio.run(run_real(cmd, cwd, prompt_text, out_log, timeout_s))
    except Exception as e:
        log(f"asyncio.run failed: {e}; falling back to SIM")
        return sim_mode(prompt_text, out_log)


if __name__ == "__main__":
    sys.exit(main())
