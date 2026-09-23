"""Run from WSL with python3 tools/verify_lab1.py; not the course grader."""
from pathlib import Path
import os
import signal
import subprocess
import time

root = Path(__file__).resolve().parents[1]
os.chdir(root)
logs = root / 'validation'
logs.mkdir(exist_ok=True)
build = subprocess.run(['make', '-j2'], capture_output=True, text=True)
(logs / 'build.log').write_text(build.stdout + build.stderr)
assert build.returncode == 0, 'Build failed; see validation/build.log'
with (logs / 'qemu.log').open('w') as out:
    qemu = subprocess.Popen(['make', 'debug'], stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        time.sleep(1)
        assert qemu.poll() is None, 'QEMU failed to start; see validation/qemu.log'
        gdb = subprocess.run(['gdb-multiarch', '-batch', '-x', 'tools/boot.gdb'], capture_output=True, text=True, timeout=30)
        trace = gdb.stdout + gdb.stderr
        (logs / 'gdb.log').write_text(trace)
        assert gdb.returncode == 0, 'GDB failed; see validation/gdb.log'
        assert '=== TAIL TO C ===' in trace, 'GDB did not reach final check'
        time.sleep(2)
    finally:
        if qemu.poll() is None:
            os.killpg(qemu.pid, signal.SIGTERM)
            try:
                qemu.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(qemu.pid, signal.SIGKILL)
                qemu.wait()
output = (logs / 'qemu.log').read_text()
assert '(THU.CST) os is loading ...' in output, 'Kernel did not print boot message'
print('PASS: build, GDB reset -> OpenSBI -> kernel -> stack -> C, kernel boot output.')
print(trace)
