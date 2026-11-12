/* Appended to proc.c only in a disposable verification copy. */
#include <clock.h>
#include <sbi.h>

extern int member3_context_probe(void);
static volatile int member3_steps[2];
static int member3_order[8], member3_order_count;

static int member3_worker(void *arg)
{
    int id = (int)(intptr_t)arg;
    uintptr_t sp;
    asm volatile("mv %0, sp" : "=r"(sp));
    assert(sp >= current->kstack && sp < current->kstack + KSTACKSIZE);
    assert((sp & 15) == 0);
    assert((read_csr(sstatus) & SSTATUS_SPP) == 0); /* sret clears SPP */
    for (int i = 0; i < 4; i++) {
        bool enabled = (i & 1) != 0;
        if (enabled) intr_enable(); else intr_disable();
        member3_order[member3_order_count++] = id;
        member3_steps[id]++;
        assert(member3_context_probe() == 0);
        assert(!!(read_csr(sstatus) & SSTATUS_SIE) == enabled);
        assert(current->pid > 1);
        assert(read_csr(satp) == (((uintptr_t)SATP_MODE_SV39 << 60) |
                                 (current->pgdir >> PGSHIFT)));
    }
    intr_disable();
    current->state = PROC_SLEEPING;
    schedule();
    panic("sleeping worker was selected");
}

void member3_tests(void)
{
    bool outer, inner;
    intr_disable();
    local_intr_save(outer);
    assert(!outer && !(read_csr(sstatus) & SSTATUS_SIE));
    local_intr_restore(outer);
    assert(!(read_csr(sstatus) & SSTATUS_SIE));
    intr_enable();
    local_intr_save(outer);
    local_intr_save(inner);
    assert(outer && !inner && !(read_csr(sstatus) & SSTATUS_SIE));
    local_intr_restore(inner);
    assert(!(read_csr(sstatus) & SSTATUS_SIE));
    local_intr_restore(outer);
    assert(read_csr(sstatus) & SSTATUS_SIE);
    intr_disable();
    cprintf("[Member3] nested interrupt save/restore PASS\n");

    /* Module 2: inspect blank PCB and the default kernel-thread stack. */
    struct proc_struct *blank = alloc_proc();
    assert(blank && blank->state == PROC_UNINIT && blank->pid == -1);
    assert(!blank->mm && !blank->tf && !blank->parent && !blank->kstack);
    assert(!blank->context.ra && !blank->runs && !blank->need_resched);
    assert(blank->pgdir == boot_pgdir_pa);
    kfree(blank);
    assert(initproc->tf->gpr.sp == (uintptr_t)initproc->tf);
    assert((initproc->tf->status & (SSTATUS_SPP | SSTATUS_SPIE)) ==
           (SSTATUS_SPP | SSTATUS_SPIE));
    assert(!(initproc->tf->status & SSTATUS_SIE));
    assert(initproc->context.sp == (uintptr_t)initproc->tf);
    assert(initproc->context.ra == (uintptr_t)forkret);
    struct trapframe frame;
    memset(&frame, 0, sizeof(frame));
    int count = nr_process;
    struct mm_struct *old_mm = current->mm;
    current->mm = (struct mm_struct *)1;
    /* Repeat to detect leaked two-page stacks on copy_mm failure. */
    size_t free_before = nr_free_pages();
    for (int i = 0; i < 20; i++) {
        assert(do_fork(0, 0, &frame) == -E_INVAL);
        assert(nr_process == count && nr_free_pages() == free_before);
    }
    current->mm = old_mm;
    nr_process = MAX_PROCESS;
    assert(do_fork(0, 0, &frame) == -E_NO_FREE_PROC);
    nr_process = count;
    cprintf("[Member3] PCB, first-run frame and fork failure cleanup PASS\n");

    initproc->state = PROC_SLEEPING;
    int idle_runs = idleproc->runs;
    schedule(); /* all registered threads blocked */
    assert(current == idleproc && idleproc->runs == idle_runs + 1);
    list_entry_t saved = proc_list;
    list_init(&proc_list);
    schedule(); /* empty queue */
    assert(current == idleproc);
    proc_list = saved;
    cprintf("[Member3] blocked and empty queue idle fallback PASS\n");

    assert(kernel_thread(member3_worker, (void *)0, 0) > 1);
    assert(kernel_thread(member3_worker, (void *)1, 0) > 1);
    clock_init();
    for (int i = 0; i < 2; i++) schedule();
    assert(current == idleproc);
    assert(member3_steps[0] == 4 && member3_steps[1] == 4);
    assert(member3_order_count == 8);
    for (int i = 0; i < 8; i++) assert(member3_order[i] == (1 - (i & 1)));
    cprintf("[Member3] round-robin, SIE=0/1 and s0-s11 context PASS\n");
    uintptr_t ra = current->context.ra;
    proc_run(current);
    assert(current == idleproc && current->context.ra == ra);
    intr_enable();
    while (ticks < 110) asm volatile("" ::: "memory");
    intr_disable();
    cprintf("[Member3] Sv39 satp and sustained timer after switches PASS\n");
    cprintf("[Member3] ALL TESTS PASS\n");
    sbi_shutdown();
    while (1) {}
}
