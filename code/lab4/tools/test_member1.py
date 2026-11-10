#!/usr/bin/env python3
"""Build a temporary PMM/VMM/trap kernel without implementing members 2/3."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
# Repository layout: code/lab4 contains sources; report contains evidence.
evidence = root.parent.parent / 'report/evidence/member1'
evidence.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
prefix = env.get('GCCPREFIX', 'riscv64-unknown-elf-')
qemu = env.get('QEMU', 'qemu-system-riscv64')

def build(directory, log):
    result = subprocess.run(['make', '-j2', 'GCCPREFIX=' + prefix], cwd=directory,
                            env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True)
    (evidence / log).write_text(result.stdout, encoding='utf-8')
    return result

with tempfile.TemporaryDirectory(prefix='lab4-member1-') as tmp:
    work = Path(tmp) / 'kernel'
    shutil.copytree(root, work, ignore=shutil.ignore_patterns(
        '.git', 'obj', 'bin', 'report', '__pycache__'))
    # Record the actual integration boundary before replacing the test entry.
    full = build(work, 'full-build.log')
    print('Full kernel build exit:', full.returncode)
    expected = ('proc_init', 'cpu_idle')
    if full.returncode and (not all(name in full.stdout for name in expected)
                            or 'fatal error:' in full.stdout):
        raise SystemExit('Full build failed for an unexpected reason; inspect full-build.log')

    init = work / 'kern/init/init.c'
    s = init.read_text(encoding='utf-8')
    s = s.replace('void grade_backtrace(void);', '''void grade_backtrace(void);
void test_lab4_pmm_basic(void);
static void member1_mapping_tests(void);''')
    s = s.replace('    proc_init(); // init process table', '''
    // The temporary test kernel stops before process creation and scheduling.
    test_lab4_pmm_basic();
    member1_mapping_tests();
    cprintf("[Member1] VMM and official PMM tests PASS\\n");
    asm volatile(".word 0xffffffff");
    asm volatile(".option push; .option norvc; ebreak; .option pop");
    cprintf("[Member1] Lab3 exception return PASS\\n");''')
    s = s.replace('    cpu_idle(); // run idle process', '''
    while (ticks < 110) { asm volatile("" : : : "memory"); }
    intr_disable();
    cprintf("[Member1] repeated timer interrupts and trap return PASS\\n");
    cprintf("[Member1] ALL TESTS PASS\\n");
    sbi_shutdown();
    while (1) {}''')
    official = (work / 'tools/test_lab4.c').read_text(encoding='utf-8')
    official = official.split('void test_lab4_process_create(void)')[0]
    s = '#include <sbi.h>\n' + s
    s += official + '\n' + (work / 'tools/test_member1.c').read_text(encoding='utf-8')
    init.write_text(s, encoding='utf-8')
    # Clear only objects inside the automatically created temporary directory.
    for name in ('obj', 'bin'):
        shutil.rmtree(work / name, ignore_errors=True)
    result = build(work, 'member1-build.log')
    if result.returncode:
        print(result.stdout[-6000:])
        raise SystemExit('Member1 test kernel build failed')
    command = [qemu, '-machine', 'virt', '-m', '128M', '-nographic', '-bios',
               'default', '-device', 'loader,file=bin/ucore.img,addr=0x80200000']
    try:
        run = subprocess.run(command, cwd=work, env=env, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, timeout=20)
        output = run.stdout
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or b''
        if isinstance(output, bytes):
            output = output.decode('utf-8', errors='replace')
        (evidence / 'member1-qemu.log').write_text(output, encoding='utf-8')
        print(output[-6000:])
        raise SystemExit('QEMU timeout; inspect member1-qemu.log')
    (evidence / 'member1-qemu.log').write_text(output, encoding='utf-8')
    print(output)
    checks = ['check_alloc_page() succeeded!', 'check_pgdir() succeeded!',
              'check_boot_pgdir() succeeded!', 'check_vma_struct() succeeded!',
              '[Test PMM] PASS', '[Member1] allocation failure and rollback PASS',
              '[Member1] same-page remap, permissions, aliases, replacement PASS',
              '[Member1] idempotent removal and free-page accounting PASS',
              '[Member1] active mapping replacement and TLB invalidation PASS',
              '[Member1] Lab3 exception return PASS',
              '[Member1] repeated timer interrupts and trap return PASS',
              '[Member1] ALL TESTS PASS']
    missing = [check for check in checks if check not in output]
    if run.returncode or missing or 'kernel panic' in output:
        raise SystemExit('FAIL: exit=%s, missing=%s' % (run.returncode, missing))
    print('PASS: member1 tests; evidence:', evidence)
