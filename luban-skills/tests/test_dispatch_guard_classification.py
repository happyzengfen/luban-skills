import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DISPATCH = ROOT / 'scripts' / 'dispatch_acp.sh'


def bash_eval(func_body: str, expression: str):
    script = f'''set -euo pipefail
source "{DISPATCH}"
{func_body}
{expression}
'''
    return subprocess.run(
        ['/bin/bash', '--noprofile', '--norc', '-c', script],
        capture_output=True,
        text=True,
        timeout=5,
    )


def test_shell_tool_line_extracts_command_for_guard():
    # 现有 shell 形式仍应继续提取命令给 guard 判定
    body = 'line="[tool] pwd: pwd"\ncmd=""\nkind="noise"\n' \
           'if classify_tool_line "$line"; then\n  :\nfi\nprintf "kind=%s\\ncmd=%s\\n" "$kind" "$cmd"\n'
    result = bash_eval('', body)
    assert result.returncode == 0, result.stderr
    assert 'kind=shell' in result.stdout
    assert 'cmd=pwd' in result.stdout


def test_acp_non_shell_tool_line_is_not_sent_to_guard():
    # 回归点：analyze image 不应被当 shell 命令送入 guard
    body = 'line="[tool] analyze image: 请分析这张室内参考图 (tc-123)"\ncmd=""\nkind="noise"\n' \
           'if classify_tool_line "$line"; then\n  :\nfi\nprintf "kind=%s\\ncmd=%s\\n" "$kind" "$cmd"\n'
    result = bash_eval('', body)
    assert result.returncode == 0, result.stderr
    assert 'kind=acp_tool' in result.stdout
    assert 'cmd=' in result.stdout
    assert 'cmd=请分析这张室内参考图' not in result.stdout


def test_guard_still_blocks_dangerous_shell_command():
    guard = ROOT / 'scripts' / 'guard.py'
    result = subprocess.run(
        ['python3', str(guard), 'match', 'rm -rf /tmp/demo'],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 1
    assert result.stdout.strip() == 'block'
