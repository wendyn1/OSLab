#!/usr/bin/env bash
set -eu
# Add the RISC-V toolchain to PATH and set QEMU_DEBUG to a symbolized QEMU.
lab_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../code/lab5" && pwd)
command -v riscv64-unknown-elf-gcc >/dev/null
command -v riscv64-unknown-elf-gdb >/dev/null
command -v gdb >/dev/null

stage=$(mktemp -d /tmp/lab05-member-a.XXXXXX)
cp -a "$lab_dir/." "$stage"
cd "$stage"
echo "STAGE=$stage"
cat >> kern/process/proc.c <<'EOF'

#include <cow.h>
#include <sbi.h>
static struct proc_struct check_proc;
static struct mm_struct *parent_mm;
static volatile int *data;
static struct Page *shared_page;
asm(
".pushsection .rodata\n"
".balign 4\n"
"check_user_start:\n"
"li a0, 18\n"
"ecall\n"
"li t0, 17\n"
"bne a0, t0, 2f\n"
"li a0, 5\n"
"ecall\n"
"li t0, -3\n"
"bne a0, t0, 2f\n"
"li a0, -1\n"
"ecall\n"
"li t0, -3\n"
"bne a0, t0, 2f\n"
"li a0, 30\n"
"li a1, 65\n"
"ecall\n"
"bnez a0, 2f\n"
"li t0, 0x801000\n"
"li t1, 23\n"
"sw t1, 0(t0)\n"
"lw t2, 0(t0)\n"
"bne t1, t2, 2f\n"
"li a1, 42\n"
"j 3f\n"
"2: li a1, 1\n"
"3: li a0, 1\n"
"ecall\n"
"1: j 1b\n"
"check_user_end:\n"
".popsection\n");
extern char check_user_start[], check_user_end[];
int do_exit(int code) {
    assert(code == 42 && *data == 23 && *(int *)page2kva(shared_page) == 14);
    assert(page_ref(shared_page) == 1);
    assert(cow_resolve_write(parent_mm, 0x801000) == 0);
    assert(get_page(parent_mm->pgdir, 0x801000, NULL) == shared_page);
    struct Page *ro = get_page(parent_mm->pgdir, 0x802000, NULL);
    assert(ro != NULL && page_ref(ro) == 2);
    assert(cow_resolve_write(parent_mm, 0x802000) == -E_FAULT);
    page_remove(current->mm->pgdir, 0x802000);
    assert(page_ref(ro) == 1);
    cprintf("\nMEMBER A SMOKE PASS\n");
    sbi_shutdown();
    for (;;) { }
}
int do_fork(uint32_t flags, uintptr_t sp, struct trapframe *tf) { return -E_UNIMP; }
int do_yield(void) { return -E_UNIMP; }
int do_kill(int pid) { return -E_UNIMP; }
int do_wait(int pid, int *status) { return -E_UNIMP; }
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size) { return -E_UNIMP; }
void schedule(void) { current->need_resched = 0; }
void proc_init(void) {
    current = &check_proc;
    current->pid = 17;
    current->mm = mm_create();
    parent_mm = mm_create();
    assert(current->mm != NULL && parent_mm != NULL);
    assert(setup_pgdir(current->mm) == 0 && setup_pgdir(parent_mm) == 0);
    assert(mm_map(current->mm, 0x800000, PGSIZE, VM_READ | VM_EXEC, NULL) == 0);
    assert(mm_map(current->mm, 0x801000, PGSIZE, VM_READ | VM_WRITE, NULL) == 0);
    assert(mm_map(parent_mm, 0x801000, PGSIZE, VM_READ | VM_WRITE, NULL) == 0);
    assert(mm_map(parent_mm, 0x802000, PGSIZE, VM_READ, NULL) == 0);
    assert(mm_map(current->mm, 0x802000, PGSIZE, VM_READ, NULL) == 0);
    struct Page *text = pgdir_alloc_page(current->mm->pgdir, 0x800000, PTE_U | PTE_R | PTE_X);
    assert(text != NULL);
    memcpy(page2kva(text), check_user_start, check_user_end - check_user_start);
    asm volatile("fence.i" ::: "memory");
    shared_page = pgdir_alloc_page(parent_mm->pgdir, 0x801000, PTE_U | PTE_R | PTE_W);
    assert(shared_page != NULL);
    *(int *)page2kva(shared_page) = 14;
    assert(pgdir_alloc_page(parent_mm->pgdir, 0x802000, PTE_U | PTE_R) != NULL);
    assert(cow_copy_range(current->mm->pgdir, parent_mm->pgdir, 0x801000, 0x803000) == 0);
    assert(page_ref(shared_page) == 2);
    data = (int *)0x801000;
}
void cpu_idle(void) {
    intr_disable();
    struct trapframe tf = {0};
    tf.gpr.sp = 0x803000;
    tf.status = (read_csr(sstatus) | SSTATUS_SPIE) & ~SSTATUS_SPP;
    tf.epc = 0x800000;
    lsatp(PADDR(current->mm->pgdir));
    forkrets(&tf);
    panic("forkrets returned");
}
EOF
make -j4 > harness-build.log 2>&1 || { tail -70 harness-build.log; exit 4; }
set -e
cat > host.gdb <<'EOF'
set pagination off
set confirm off
set breakpoint pending on
break helper_raise_exception if env->pc == 0x800002
commands
silent
printf "HOST_ECALL pc=%#lx priv=%lu exception=%u\n", env->pc, env->priv, exception
bt 2
continue
end
break helper_sret if env->sepc == 0x800006
commands
silent
printf "HOST_SRET pc=%#lx sepc=%#lx priv=%lu\n", env->pc, env->sepc, env->priv
bt 2
continue
end
run
EOF
qemu_debug=${QEMU_DEBUG:-/opt/riscv/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64}
gdb -q -batch -x host.gdb --args "$qemu_debug" -machine virt -nographic -bios default -device loader,file=bin/ucore.img,addr=0x80200000 -gdb tcp:127.0.0.1:12457 -S -d in_asm,int -D guest-trace.log > guest-console.log 2>&1 &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true' EXIT
sleep 2
cat > guest.gdb <<'EOF'
set pagination off
file bin/kernel
set architecture riscv:rv64
target remote localhost:12457
hbreak *0x800000
continue
si
x/i $pc
info registers pc a0 a1 sp
set $resume_pc = $pc + 4
tbreak syscall
continue
info registers pc a0 sp
x/xg &current->tf->cause
x/xg &current->tf->epc
hbreak *$resume_pc
continue
x/i $pc
info registers pc a0 sp
detach
EOF
timeout 12s riscv64-unknown-elf-gdb -batch -x guest.gdb > guest-gdb.log 2>&1 || true
tail -40 guest-gdb.log
grep -iE 'user_ecall|store_page_fault|sret|ecall' guest-trace.log | tail -20 || true
timeout 12s tail --pid="$qemu_pid" -f /dev/null || kill "$qemu_pid" 2>/dev/null || true
wait "$qemu_pid" || true
grep -A3 'HOST_\|Error\|Cannot\|No symbol\|SMOKE PASS' guest-console.log || true
grep -q '^HOST_ECALL' guest-console.log
grep -q '^HOST_SRET' guest-console.log
grep -q 'MEMBER A SMOKE PASS' guest-console.log
