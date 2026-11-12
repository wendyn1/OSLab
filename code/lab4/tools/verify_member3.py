#!/usr/bin/env python3
"""Run Lab4 build, original grading and supplemental scheduling checks in copies."""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
evidence = root.parent.parent / 'report/evidence/member3'
evidence.mkdir(parents=True, exist_ok=True)


def run(command, cwd, name, timeout=240, expected=0):
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        (evidence / name).write_bytes(exc.stdout or b'')
        raise RuntimeError('timeout; see ' + name) from exc
    (evidence / name).write_bytes(result.stdout)
    if result.returncode != expected:
        raise RuntimeError(f'{command}: exit {result.returncode}; see {name}')
    return result.stdout.decode(errors='replace')


with tempfile.TemporaryDirectory(prefix='lab4-member3-') as tmp:
    work = Path(tmp) / 'code/lab4'
    shutil.copytree(root, work, ignore=shutil.ignore_patterns('obj', 'bin', '__pycache__', '.qemu*'))
    # Shell scripts checked out by older Windows clients can have CRLF.
    for path in work.rglob('*.sh'):
        path.write_text(path.read_text())
    run(['make', '-j2'], work, 'build.log')
    print('PASS: full kernel build', flush=True)
    # Keep existing member1 historical evidence intact; collect fresh regression separately.
    run(['python3', 'tools/test_member1.py'], work, 'member1-regression.log')
    print('PASS: member1 regression', flush=True)
    run(['make', 'grade'], work, 'grade.log')
    print('PASS: original grading', flush=True)
    proc = work / 'kern/process/proc.c'
    proc.write_text(proc.read_text() + '\n' + (root / 'tools/test_member3.c').read_text())
    init = work / 'kern/init/init.c'
    source = init.read_text().replace('void grade_backtrace(void);',
                                     'void grade_backtrace(void);\nvoid member3_tests(void);')
    source = source.replace('    proc_init(); // init process table',
                            '    proc_init(); // init process table\n    member3_tests();')
    init.write_text(source)
    # Add an ABI-conforming register probe to the existing switch compilation unit.
    switch = work / 'kern/process/switch.S'
    probe = ['\n.globl member3_context_probe\nmember3_context_probe:', 'addi sp, sp, -112', 'sd ra, 0(sp)']
    for i in range(12): probe += [f'sd s{i}, {8 * (i + 1)}(sp)', f'li s{i}, {0x300 + i}']
    probe += ['call schedule', 'li a0, 0']
    for i in range(12): probe += [f'li t0, {0x300 + i}', f'bne s{i}, t0, .Lprobe_fail']
    probe += ['j .Lprobe_done', '.Lprobe_fail:', 'li a0, 1', '.Lprobe_done:']
    for i in range(12): probe += [f'ld s{i}, {8 * (i + 1)}(sp)']
    probe += ['ld ra, 0(sp)', 'addi sp, sp, 112', 'ret']
    switch.write_text(switch.read_text() + '\n'.join(probe) + '\n')
    run(['make', '-j2'], work, 'supplemental-build.log')
    output = run(['qemu-system-riscv64', '-machine', 'virt', '-nographic', '-bios', 'default',
                  '-device', 'loader,file=bin/ucore.img,addr=0x80200000', '-monitor', 'none'],
                 work, 'supplemental-boot.log', timeout=25)
    if '[Member3] ALL TESTS PASS' not in output or 'kernel panic' in output:
        raise RuntimeError('supplemental checks failed; see supplemental-boot.log')
    (evidence / 'summary.txt').write_text(
        'PASS: full kernel compile and link\nPASS: member1 mapping/trap/timer regression\n'
        'PASS: original Lab4 grading (see grade.log for score)\n'
        'PASS: nested interrupt save/restore\nPASS: PCB, initial stack/status, fork failure cleanup\n'
        'PASS: empty/blocked idle fallback and round-robin order\n'
        'PASS: s0-s11, stack/return, SIE=0/1, Sv39 satp and continuous timer\n')
    print((evidence / 'summary.txt').read_text())
