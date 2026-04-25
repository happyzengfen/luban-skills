#!/usr/bin/env python3
"""
guard.py — 工具调用审批守门（luban 自有，不依赖其他 skill）

用法:
  guard.py match "<cmd>"         → 打印 allow|block，退出码 0|1
  guard.py check <rules_file>     → 校验规则文件合法性

规则来源（优先级从高到低）:
  1. $GUARD_RULES_PATH  自定义 YAML
  2. luban-skills/references/allowlist-default.yaml
  3. 内置最小白名单（pwd / ls / cat / head / tail / wc / grep / find / python3 / bash）

规则格式（YAML）:
  allow:
    - "^pwd$"
    - "^ls (-[alh]+ )?[/\\w.-]*$"
    - "^cat [/\\w.-]+$"
  block:
    - "rm -rf"
    - "chmod"
    - "chown"

匹配规则:
  - 命令字符串先 match block（任一命中 → block）
  - 再 match allow（任一命中 → allow）
  - 都没命中 → block（默认拒绝）
"""
import os
import re
import sys
import pathlib

DEFAULT_ALLOW = [
    r"^pwd$",
    r"^ls(\s+-[alhRtS1]+)?(\s+[/\w.\-]*)?$",
    r"^cat\s+[/\w.\-]+$",
    r"^head(\s+-n\s+\d+)?\s+[/\w.\-]+$",
    r"^tail(\s+-n\s+\d+)?\s+[/\w.\-]+$",
    r"^wc(\s+-l)?\s+[/\w.\-]+$",
    r"^grep(\s+-[inHr]+)?\s+.{1,200}$",
    r"^find\s+[/\w.\-]+.{0,200}$",
    r"^echo\s+.{0,200}$",
    r"^date(\s+.{0,50})?$",
    r"^python3\s+-c\s+.{1,400}$",
]
DEFAULT_BLOCK = [
    r"\brm\s+-rf?\b",
    r"\bmkfs\b",
    r"\bdd\s+if=",
    r"\bchmod\b",
    r"\bchown\b",
    r"\bsudo\b",
    r"\bcurl\s+[^|]*\|\s*sh",
    r"\bwget\s+[^|]*\|\s*sh",
    r"\bgit\s+push\s+.*--force",
    r"\bgit\s+reset\s+--hard",
    r":\s*\(\s*\)\s*\{.*\}\s*;",  # fork bomb
]


def load_rules():
    allow, block = list(DEFAULT_ALLOW), list(DEFAULT_BLOCK)
    candidates = [os.environ.get("GUARD_RULES_PATH")]
    here = pathlib.Path(__file__).resolve().parent.parent
    candidates.append(str(here / "references" / "allowlist-default.yaml"))
    for p in candidates:
        if not p or not os.path.exists(p):
            continue
        try:
            import yaml
            data = yaml.safe_load(pathlib.Path(p).read_text(encoding="utf-8")) or {}
        except ImportError:
            # 无 PyYAML 时的简易解析：只认 "allow:" / "block:" 下的 `- "regex"` 行
            # YAML 双引号字符串里 `\s` 按 YAML 规范会当字面 \s；我们要还原 YAML 的转义
            data = {"allow": [], "block": []}
            cur = None
            for raw in pathlib.Path(p).read_text(encoding="utf-8").splitlines():
                line = raw.rstrip()
                if line.startswith("allow:"):
                    cur = "allow"; continue
                if line.startswith("block:"):
                    cur = "block"; continue
                if cur and line.lstrip().startswith("- "):
                    val = line.lstrip()[2:].strip()
                    # 剥引号
                    if (val.startswith('"') and val.endswith('"')) or \
                       (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    # YAML 双引号语义：\\ 表示单个 \ ；处理这个常见情况
                    val = val.replace("\\\\", "\\")
                    data[cur].append(val)
        except Exception as e:
            print(f"[guard] rules load failed: {e}", file=sys.stderr)
            continue
        if isinstance(data.get("allow"), list):
            allow = data["allow"]
        if isinstance(data.get("block"), list):
            block = data["block"]
        break
    return allow, block


def match_cmd(cmd: str) -> str:
    allow, block = load_rules()
    cmd = cmd.strip()
    if not cmd:
        return "block"
    for pat in block:
        try:
            if re.search(pat, cmd):
                return "block"
        except re.error:
            continue
    for pat in allow:
        try:
            if re.match(pat, cmd):
                return "allow"
        except re.error:
            continue
    return "block"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: guard.py match <cmd> | check <rules_file>", file=sys.stderr)
        return 2
    action = sys.argv[1]
    if action == "match":
        cmd = " ".join(sys.argv[2:]).strip()
        verdict = match_cmd(cmd)
        print(verdict)
        return 0 if verdict == "allow" else 1
    if action == "check":
        try:
            import yaml
            rules = yaml.safe_load(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")) or {}
            for key in ("allow", "block"):
                for pat in rules.get(key, []) or []:
                    re.compile(pat)
            print("RULES_OK")
            return 0
        except Exception as e:
            print(f"RULES_FAIL {e}", file=sys.stderr)
            return 1
    print(f"unknown action: {action}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
