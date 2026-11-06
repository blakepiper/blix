"""Verify suspend routing and refusal paths without touching logind or hardware."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

source = sys.argv[1]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    fake = root / 'command'
    fake.write_text(f'''#!{sys.executable}
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
session = os.environ.get('TEST_SESSION', 'wayland')
if name == 'notify-send':
    raise SystemExit(0)
if name == 'systemctl':
    if 'is-active' in args:
        target = args[-1]
        expected = ['blix-wayland-session.target', 'blix-wayland-lock.service'] if session == 'wayland' else ['blix-session.target', 'blix-lock.service']
        raise SystemExit(0 if session != 'none' and target in expected else 3)
    if 'show' in args:
        print('42')
    elif args == ['suspend']:
        Path(os.environ['TEST_RESULT']).write_text('suspend')
    else:
        raise SystemExit('Unexpected systemctl operation: ' + repr(args))
elif name == 'busctl':
    if args[-1] == 'ListInhibitors':
        pid = 99 if os.environ.get('TEST_MISSING_INHIBITOR') else 42
        print(json.dumps({{'data': [[['sleep', 'test-locker', 'przvl', 'delay', 1000, pid]]]}}))
    elif args[-1] == 'CanSuspend':
        print(json.dumps({{'data': [os.environ.get('TEST_CAN_SUSPEND', 'yes')]}}))
    else:
        raise SystemExit('Unexpected bus operation')
''')
    fake.chmod(0o755)
    for name in ('systemctl', 'busctl', 'notify-send'):
        (root / name).symlink_to(fake)
    result = root / 'result'
    base = {**os.environ, 'PATH': str(root) + ':' + os.environ['PATH'], 'TEST_RESULT': str(result)}
    for session in ('wayland', 'x11'):
        env = {**base, 'TEST_SESSION': session}
        checked = subprocess.run(['bash', source, '--check'], env=env, capture_output=True, text=True)
        assert checked.returncode == 0, checked.stderr
        assert not result.exists(), '--check must never suspend'
        applied = subprocess.run(['bash', source], env=env, capture_output=True, text=True)
        assert applied.returncode == 0, applied.stderr
        assert result.read_text() == 'suspend'
        result.unlink()
    for override in ({'TEST_SESSION': 'none'}, {'TEST_MISSING_INHIBITOR': '1'}, {'TEST_CAN_SUSPEND': 'no'}):
        failed = subprocess.run(['bash', source], env={**base, **override}, capture_output=True, text=True)
        assert failed.returncode != 0, override
        assert not result.exists(), 'An unprotected or unsupported request must not suspend'
