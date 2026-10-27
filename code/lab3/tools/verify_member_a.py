#!/usr/bin/env python3
"""WSL/Linux: isolated member-A integration test; never edits student sources.

Usage: python3 verify_member_a.py /path/to/code/lab3 /path/to/output-directory
Requires make, riscv64-unknown-elf-{gcc,objdump,gdb}, QEMU, and Python 3.
The exception handlers below are TEST DOUBLES, not the module-two solution.
"""
from pathlib import Path
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

src = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
versions = '\n'.join(subprocess.check_output([tool,'--version'],text=True).splitlines()[0]
    for tool in ('riscv64-unknown-elf-gcc','riscv64-unknown-elf-gdb','qemu-system-riscv64','make'))
(out/'environment.txt').write_text(versions+'\n',encoding='utf-8')
# QEMU v4.1.1 helper_sret explicitly writes SPIE=0; record this old-emulator
# behavior rather than changing the student's architectural restore code.
expected_spie = 0 if 'QEMU emulator version 4.1.1' in versions else 1
root = Path(tempfile.mkdtemp(prefix='lab3-member-a-')) / 'lab3'
shutil.copytree(src, root, ignore=shutil.ignore_patterns('obj', 'bin', '.git', '__pycache__'))
def read(p): return p.read_text(encoding='utf-8')
def write(p, s): p.write_text(s, encoding='utf-8')
write(out/'test-directory.txt', str(root)+'\n')

p = root/'kern/trap/trap.c'
s = read(p)
assert s.count('//lab3 function2 YOUR CODE') == 1, 'Expected untouched module-two placeholder'
s = s.replace('//lab3 function2 YOUR CODE', r'''
/* TEST DOUBLE: supports only the deliberate breakpoints in this probe. */
static unsigned member_a_count;
void interrupt_handler(struct trapframe *tf) {
    panic("unexpected interrupt in member-A isolated test");
}
void exception_handler(struct trapframe *tf) {
    assert(tf->cause == CAUSE_BREAKPOINT);
    assert(sizeof(struct trapframe) == 36 * sizeof(uintptr_t));
    assert((uintptr_t)&tf->status - (uintptr_t)tf == 32 * sizeof(uintptr_t));
    assert((uintptr_t)&tf->epc - (uintptr_t)tf == 33 * sizeof(uintptr_t));
    assert((uintptr_t)&tf->badvaddr - (uintptr_t)tf == 34 * sizeof(uintptr_t));
    assert((uintptr_t)&tf->cause - (uintptr_t)tf == 35 * sizeof(uintptr_t));
    assert(tf->gpr.sp == (uintptr_t)tf + sizeof(*tf));
    assert(((uintptr_t)tf & 15) == 0);
    unsigned length = (*(volatile unsigned short *)tf->epc & 3) == 3 ? 4 : 2;
    cprintf("MEMBER_A_TRAP %u length=%u frame=%p saved_sp=%p epc=%p\n",
            ++member_a_count, length, tf, tf->gpr.sp, tf->epc);
    tf->epc += length;
}
''')
write(p, s)
p = root/'kern/init/init.c'
s = read(p).replace('#include <dtb.h>', '#include <dtb.h>\n#include <sbi.h>\nextern void member_a_probe(void);')
anchor = '    clock_init();'
assert anchor in s
s = s.replace(anchor, '''    member_a_probe();  // SIE=0
    intr_enable();
    member_a_probe();  // SIE=1; no timer has been armed
    intr_disable();
    cprintf("MEMBER_A_RUNTIME_PASS: four breakpoint returns\\n");
    sbi_shutdown();
    while (1) {}
    clock_init();''',1)
write(p,s)

# ABI-correct caller: preserve the twelve callee-saved registers and ra.
callee = [1,8,9]+list(range(18,28))
asm = '.text\n.align 2\n.globl member_a_probe\nmember_a_probe:\n    addi sp, sp, -112\n'
asm += ''.join(f'    sd x{r}, {i*8}(sp)\n' for i,r in enumerate(callee))
asm += ''.join(f'    li x{r}, {0x100+r}\n' for r in range(5,32))
asm += '''.globl member_a_pre16
member_a_pre16:
    c.ebreak
.globl member_a_post16
member_a_post16:
    nop
    .option push
    .option norvc
.globl member_a_pre32
member_a_pre32:
    ebreak
.globl member_a_post32
member_a_post32:
    nop
    .option pop
'''
asm += ''.join(f'    ld x{r}, {i*8}(sp)\n' for i,r in enumerate(callee))
asm += '    addi sp, sp, 112\n    ret\n'
write(root/'kern/init/member_a_probe.S',asm)

def run(args, log, timeout=60):
    with (out/log).open('w') as f:
        p = subprocess.run(args,cwd=root,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
    if p.returncode:
        raise RuntimeError(f'{args[0]} failed ({p.returncode}); see {out/log}')

run(['make','-j2'],'build.log')
run(['riscv64-unknown-elf-objdump','-d','bin/kernel'],'disassembly.log')
dis = read(out/'disassembly.log')
ret_block = dis.split('<__trapret>:')[1].split('\n\n')[0]
m = re.search(r'^\s*([0-9a-f]+):.*\bsret\b',ret_block,re.M)
assert m, 'sret not found'
sret_addr = m.group(1)

g = ['set pagination off','set confirm off','set architecture riscv:rv64',
     'file bin/kernel','set $completed = 0','set $entered = 0',
     'set $called = 0','set $restored = 0']
def check(expr, label):
    return [f'if !({expr})',f'printf "FAIL: {label}\\n"','quit 1','end']
for bits in (16,32):
    g += [f'break *member_a_pre{bits}','commands','silent',f'set $length = {bits//8}',
          'set $before_pc = $pc','set $before_status = $sstatus']
    g += [f'set $saved{r} = $x{r}' for r in range(32)]
    g += ['printf "BEFORE length=%d pc=%#lx sp=%#lx status=%#lx\\n", $length, $pc, $sp, $sstatus','continue','end']
    g += [f'break *member_a_post{bits}','commands','silent']
    for r in range(32): g += check(f'$x{r} == $saved{r}', f'post-return x{r}')
    g += check('$pc == $before_pc + $length','post-return PC')
    g += check('($sstatus & 2) == ($before_status & 2)','post-return SIE')
    g += ['printf "POST_SRET status=%#lx (SPP=%d SPIE=%d)\\n", $sstatus, ($sstatus >> 8) & 1, ($sstatus >> 5) & 1']
    g += check(f'(($sstatus >> 5) & 1) == {expected_spie} && ($sstatus & 0x100) == 0','sret SPP and version-specific SPIE')
    g += ['set $completed = $completed + 1','printf "AFTER PASS: all 32 GPR slots, sp, PC, SIE; count=%d status=%#lx\\n", $completed, $sstatus','continue','end']
# Inspect hardware Trap state at the C entry, after SAVE_ALL. On QEMU 4.1,
# continuing over the trigger breakpoint can skip an entry-address breakpoint.
g += ['break *trap','commands','silent','set $entry_status = $sstatus']
g += check('$sepc == $before_pc && $scause == 3','entry sepc/cause')
g += check('($sstatus & 2) == 0 && ($sstatus & 0x100) != 0','entry SIE/SPP')
g += check('(($sstatus >> 5) & 1) == (($before_status >> 1) & 1)','entry SPIE')
g += ['set $entered = $entered + 1']
g += check('$a0 == $sp && $sp == $saved2 - 288 && ((unsigned long)$sp & 15) == 0','C ABI frame pointer and alignment')
for r in range(32): g += check(f'*(unsigned long *)($a0 + {r*8}) == $saved{r}', f'frame x{r}')
g += check('*(unsigned long *)($a0+256) == $entry_status','saved status')
g += check('*(unsigned long *)($a0+264) == $before_pc','saved epc')
g += check('*(unsigned long *)($a0+272) == $stval','saved stval')
g += check('*(unsigned long *)($a0+280) == $scause','saved scause')
g += ['set $called = $called + 1','printf "TRAP ABI PASS: a0=%#lx frame_size=288\\n", $a0','continue','end']
g += [f'break *0x{sret_addr}','commands','silent']
for r in range(32): g += check(f'$x{r} == $saved{r}',f'before sret x{r}')
g += check('$sepc == $before_pc + $length','restored sepc')
g += check('$sstatus == $entry_status','restored sstatus')
g += ['set $restored = $restored + 1','printf "RESTORE PASS: sp=%#lx sepc=%#lx status=%#lx\\n", $sp, $sepc, $sstatus','continue','end']
g += ['break *sbi_shutdown','commands','silent']
g += check('$completed == 4 && $entered == 4 && $called == 4 && $restored == 4','four complete trap lifecycles')
g += ['printf "MEMBER_A_GDB_PASS: 4 lifecycles, 16/32-bit breakpoints, SIE=0/1\\n"','detach','quit 0','end']

with socket.socket() as sock:
    sock.bind(('127.0.0.1',0))
    port = sock.getsockname()[1]
g += [f'target remote 127.0.0.1:{port}','continue']
write(out/'verify.gdb','\n'.join(g)+'\n')
with (out/'boot.log').open('w') as log:
    qemu = subprocess.Popen(['qemu-system-riscv64','-machine','virt','-nographic','-bios','default',
        '-device','loader,file=bin/ucore.img,addr=0x80200000','-monitor','none',
        '-gdb',f'tcp:127.0.0.1:{port}','-S'],cwd=root,stdout=log,stderr=subprocess.STDOUT)
    try:
        time.sleep(0.5)
        run(['riscv64-unknown-elf-gdb','-q','-batch','-x',str(out/'verify.gdb')],'gdb.log',60)
        assert qemu.wait(timeout=10) == 0
    finally:
        if qemu.poll() is None:
            qemu.terminate()
            qemu.wait(timeout=10)
assert 'MEMBER_A_GDB_PASS' in read(out/'gdb.log')
assert 'MEMBER_A_RUNTIME_PASS' in read(out/'boot.log')
print('PASS; logs:',out)
print('Temporary test source:',root)
