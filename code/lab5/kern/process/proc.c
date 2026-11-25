#include <proc.h>
#include <kmalloc.h>
#include <string.h>
#include <sync.h>
#include <pmm.h>
#include <error.h>
#include <sched.h>
#include <elf.h>
#include <vmm.h>
#include <trap.h>
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>

/* ------------- process/thread mechanism design&implementation -------------
(an simplified Linux process/thread mechanism )
introduction:
  ucore implements a simple process/thread mechanism. process contains the independent memory sapce, at least one threads
for execution, the kernel data(for management), processor state (for context switch), files(in lab6), etc. ucore needs to
manage all these details efficiently. In ucore, a thread is just a special kind of process(share process's memory).
------------------------------
process state       :     meaning               -- reason
    PROC_UNINIT     :   uninitialized           -- alloc_proc
    PROC_SLEEPING   :   sleeping                -- try_free_pages, do_wait, do_sleep
    PROC_RUNNABLE   :   runnable(maybe running) -- proc_init, wakeup_proc,
    PROC_ZOMBIE     :   almost dead             -- do_exit

-----------------------------
process state changing:

  alloc_proc                                 RUNNING
      +                                   +--<----<--+
      +                                   + proc_run +
      V                                   +-->---->--+
PROC_UNINIT -- proc_init/wakeup_proc --> PROC_RUNNABLE -- try_free_pages/do_wait/do_sleep --> PROC_SLEEPING --
                                           A      +                                                           +
                                           |      +--- do_exit --> PROC_ZOMBIE                                +
                                           +                                                                  +
                                           -----------------------wakeup_proc----------------------------------
-----------------------------
process relations
parent:           proc->parent  (proc is children)
children:         proc->cptr    (proc is parent)
older sibling:    proc->optr    (proc is younger sibling)
younger sibling:  proc->yptr    (proc is older sibling)
-----------------------------
related syscall for process:
SYS_exit        : process exit,                           -->do_exit
SYS_fork        : create child process, dup mm            -->do_fork-->wakeup_proc
SYS_wait        : wait process                            -->do_wait
SYS_exec        : after fork, process execute a program   -->load a program and refresh the mm
SYS_clone       : create child thread                     -->do_fork-->wakeup_proc
SYS_yield       : process flag itself need resecheduling, -- proc->need_sched=1, then scheduler will rescheule this process
SYS_sleep       : process sleep                           -->do_sleep
SYS_kill        : kill process                            -->do_kill-->proc->flags |= PF_EXITING
                                                                 -->wakeup_proc-->do_wait-->do_exit
SYS_getpid      : get the process's pid

*/

// the process set's list
list_entry_t proc_list;

#define HASH_SHIFT 10
#define HASH_LIST_SIZE (1 << HASH_SHIFT)
#define pid_hashfn(x) (hash32(x, HASH_SHIFT))

// has list for process set based on pid
static list_entry_t hash_list[HASH_LIST_SIZE];

// idle proc
struct proc_struct *idleproc = NULL;
// init proc
struct proc_struct *initproc = NULL;
// current proc
struct proc_struct *current = NULL;

static int nr_process = 0;

void kernel_thread_entry(void);
void forkrets(struct trapframe *tf);
void switch_to(struct context *from, struct context *to);

//lab4 请补充你在lab4中的代码

static struct proc_struct *
alloc_proc(void)
{
    struct proc_struct *proc = kmalloc(sizeof(*proc));
    if (proc != NULL) {
        memset(proc, 0, sizeof(*proc));
        proc->state = PROC_UNINIT;
        proc->pid = -1;
        proc->pgdir = boot_pgdir_pa;
        list_init(&proc->list_link);
        list_init(&proc->hash_link);
    }
    return proc;
}


// set_proc_name - set the name of proc
char *
set_proc_name(struct proc_struct *proc, const char *name)
{
    memset(proc->name, 0, sizeof(proc->name));
    return memcpy(proc->name, name, PROC_NAME_LEN);
}

// get_proc_name - get the name of proc
char *
get_proc_name(struct proc_struct *proc)
{
    static char name[PROC_NAME_LEN + 1];
    memset(name, 0, sizeof(name));
    return memcpy(name, proc->name, PROC_NAME_LEN);
}

// set_links - set the relation links of process
static void
set_links(struct proc_struct *proc)
{
    list_add(&proc_list, &(proc->list_link));
    proc->yptr = NULL;
    if ((proc->optr = proc->parent->cptr) != NULL)
    {
        proc->optr->yptr = proc;
    }
    proc->parent->cptr = proc;
    nr_process++;
}

// remove_links - clean the relation links of process
static void
remove_links(struct proc_struct *proc)
{
    list_del(&(proc->list_link));
    if (proc->optr != NULL)
    {
        proc->optr->yptr = proc->yptr;
    }
    if (proc->yptr != NULL)
    {
        proc->yptr->optr = proc->optr;
    }
    else
    {
        proc->parent->cptr = proc->optr;
    }
    nr_process--;
}

// get_pid - alloc a unique pid for process
static int
get_pid(void)
{
    static_assert(MAX_PID > MAX_PROCESS);
    struct proc_struct *proc;
    list_entry_t *list = &proc_list, *le;
    static int next_safe = MAX_PID, last_pid = MAX_PID;
    if (++last_pid >= MAX_PID)
    {
        last_pid = 1;
        goto inside;
    }
    if (last_pid >= next_safe)
    {
    inside:
        next_safe = MAX_PID;
    repeat:
        le = list;
        while ((le = list_next(le)) != list)
        {
            proc = le2proc(le, list_link);
            if (proc->pid == last_pid)
            {
                if (++last_pid >= next_safe)
                {
                    if (last_pid >= MAX_PID)
                    {
                        last_pid = 1;
                    }
                    next_safe = MAX_PID;
                    goto repeat;
                }
            }
            else if (proc->pid > last_pid && next_safe > proc->pid)
            {
                next_safe = proc->pid;
            }
        }
    }
    return last_pid;
}






// forkret -- the first kernel entry point of a new thread/process
// NOTE: the addr of forkret is setted in copy_thread function
//       after switch_to, the current proc will execute here.
static void
forkret(void)
{
    forkrets(current->tf);
}

// hash_proc - add proc into proc hash_list
static void
hash_proc(struct proc_struct *proc)
{
    list_add(hash_list + pid_hashfn(proc->pid), &(proc->hash_link));
}

// unhash_proc - delete proc from proc hash_list
static void
unhash_proc(struct proc_struct *proc)
{
    list_del(&(proc->hash_link));
}

// find_proc - find proc frome proc hash_list according to pid
struct proc_struct *
find_proc(int pid)
{
    if (0 < pid && pid < MAX_PID)
    {
        list_entry_t *list = hash_list + pid_hashfn(pid), *le = list;
        while ((le = list_next(le)) != list)
        {
            struct proc_struct *proc = le2proc(le, hash_link);
            if (proc->pid == pid)
            {
                return proc;
            }
        }
    }
    return NULL;
}

int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags)
{
    struct trapframe tf;
    memset(&tf, 0, sizeof(tf));
    tf.gpr.s0 = (uintptr_t)fn;
    tf.gpr.s1 = (uintptr_t)arg;
    tf.status = (read_csr(sstatus) | SSTATUS_SPP | SSTATUS_SPIE) & ~SSTATUS_SIE;
    tf.epc = (uintptr_t)kernel_thread_entry;
    return do_fork(clone_flags | CLONE_VM, 0, &tf);
}


// setup_kstack - alloc pages with size KSTACKPAGE as process kernel stack
static int
setup_kstack(struct proc_struct *proc)
{
    struct Page *page = alloc_pages(KSTACKPAGE);
    if (page != NULL)
    {
        proc->kstack = (uintptr_t)page2kva(page);
        return 0;
    }
    return -E_NO_MEM;
}

// put_kstack - free the memory space of process kernel stack
static void
put_kstack(struct proc_struct *proc)
{
    free_pages(kva2page((void *)(proc->kstack)), KSTACKPAGE);
}

// setup_pgdir - alloc one page as PDT
static int
setup_pgdir(struct mm_struct *mm)
{
    struct Page *page;
    if ((page = alloc_page()) == NULL)
    {
        return -E_NO_MEM;
    }
    pde_t *pgdir = page2kva(page);
    memcpy(pgdir, boot_pgdir_va, PGSIZE);

    mm->pgdir = pgdir;
    return 0;
}

// put_pgdir - free the memory space of PDT
static void
put_pgdir(struct mm_struct *mm)
{
    free_page(kva2page(mm->pgdir));
}

//lab5 function3 2411061 update copy_mm
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc)
{
    struct mm_struct *old = current->mm;
    if (old == NULL) return 0; // 内核线程继续共用内核页表。
    struct mm_struct *mm = old;
    int ret = 0;
    if (!(clone_flags & CLONE_VM)) {
        mm = mm_create();
        if (mm == NULL) return -E_NO_MEM;
        if ((ret = setup_pgdir(mm)) != 0) {
            mm_destroy(mm);
            return ret;
        }
        lock_mm(old);
        ret = dup_mmap(mm, old);
        unlock_mm(old);
        if (ret != 0) {
            // 子地址空间尚未发布，按映射、根表、描述结构逆序清理。
            exit_mmap(mm);
            put_pgdir(mm);
            mm_destroy(mm);
            return ret;
        }
    }
    mm_count_inc(mm);
    proc->mm = mm;
    proc->pgdir = PADDR(mm->pgdir);
    return 0;
}



static int load_icode(unsigned char *binary, size_t size)
{
    if (binary == NULL || size < sizeof(struct elfhdr)) return -E_INVAL_ELF;
    struct elfhdr *elf = (struct elfhdr *)binary;
    if (elf->e_magic != ELF_MAGIC || elf->e_phentsize != sizeof(struct proghdr) ||
        elf->e_phoff > size || elf->e_phnum > (size - elf->e_phoff) / sizeof(struct proghdr)) {
        return -E_INVAL_ELF;
    }
    struct mm_struct *mm = mm_create();
    if (mm == NULL) return -E_NO_MEM;
    int ret = setup_pgdir(mm);
    if (ret != 0) goto fail_mm;
    for (size_t i = 0; i < elf->e_phnum; i++) {
        struct proghdr *ph = (struct proghdr *)(binary + elf->e_phoff + i * sizeof(*ph));
        if (ph->p_type != ELF_PT_LOAD) continue;
        if (ph->p_filesz > ph->p_memsz || ph->p_offset > size ||
            ph->p_filesz > size - ph->p_offset || ph->p_memsz == 0 ||
            ph->p_va + ph->p_memsz < ph->p_va ||
            !USER_ACCESS(ph->p_va, ph->p_va + ph->p_memsz)) {
            ret = -E_INVAL_ELF;
            goto fail_pgdir;
        }
        uint32_t vm_flags = 0, perm = PTE_U | PTE_R;
        if (ph->p_flags & ELF_PF_R) vm_flags |= VM_READ;
        if (ph->p_flags & ELF_PF_W) { vm_flags |= VM_WRITE; perm |= PTE_W; }
        if (ph->p_flags & ELF_PF_X) { vm_flags |= VM_EXEC; perm |= PTE_X; }
        ret = mm_map(mm, ph->p_va, ph->p_memsz, vm_flags, NULL);
        if (ret != 0) goto fail_pgdir;
        for (uintptr_t la = ROUNDDOWN(ph->p_va, PGSIZE);
             la < ROUNDUP(ph->p_va + ph->p_memsz, PGSIZE); la += PGSIZE) {
            struct Page *page = pgdir_alloc_page(mm->pgdir, la, perm | PTE_W);
            if (page == NULL) { ret = -E_NO_MEM; goto fail_pgdir; }
            memset(page2kva(page), 0, PGSIZE);
            uintptr_t file_start = ph->p_va, file_end = ph->p_va + ph->p_filesz;
            uintptr_t from = la > file_start ? la : file_start;
            uintptr_t to = la + PGSIZE < file_end ? la + PGSIZE : file_end;
            if (from < to) memcpy((char *)page2kva(page) + from - la,
                                  binary + ph->p_offset + from - ph->p_va, to - from);
            pte_t *ptep = get_pte(mm->pgdir, la, 0);
            if (ptep != NULL) *ptep = (*ptep & ~PTE_W) | (perm & PTE_W);
        }
    }
    ret = mm_map(mm, USTACKTOP - USTACKSIZE, USTACKSIZE,
                 VM_READ | VM_WRITE | VM_STACK, NULL);
    if (ret != 0) goto fail_pgdir;
    for (uintptr_t la = USTACKTOP - 4 * PGSIZE; la < USTACKTOP; la += PGSIZE) {
        struct Page *page = pgdir_alloc_page(mm->pgdir, la, PTE_U | PTE_R | PTE_W);
        if (page == NULL) {
            ret = -E_NO_MEM;
            goto fail_pgdir;
        }
        // 2411061：占位区外装载修复，不能把上一个使用者的物理页内容暴露为用户栈。
        memset(page2kva(page), 0, PGSIZE);
    }
    mm_count_inc(mm);
    current->mm = mm;
    current->pgdir = PADDR(mm->pgdir);
    uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                           (current->pgdir >> RISCV_PGSHIFT);
    asm volatile("csrw satp, %0" :: "r"(satp_value) : "memory");
    flush_tlb();
    struct trapframe *tf = current->tf;
    memset(tf, 0, sizeof(*tf));
    tf->gpr.sp = USTACKTOP;
    tf->epc = elf->e_entry;
    tf->status = (read_csr(sstatus) | SSTATUS_SPIE) & ~(SSTATUS_SPP | SSTATUS_SIE);
    return 0;
fail_pgdir:
    exit_mmap(mm);
    put_pgdir(mm);
fail_mm:
    mm_destroy(mm);
    return ret;
}


//lab5 function3 2411061
static void copy_thread(struct proc_struct *proc, uintptr_t stack,
                        struct trapframe *tf)
{
    proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE - sizeof(*tf));
    *proc->tf = *tf;
    proc->tf->gpr.a0 = 0; // 子进程从相同用户返回位置获得 fork 返回值零。
    proc->tf->gpr.sp = stack ? stack : (uintptr_t)proc->tf;
    proc->context.ra = (uintptr_t)forkret;
    proc->context.sp = (uintptr_t)proc->tf;
}

int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf)
{
    if (nr_process >= MAX_PROCESS) return -E_NO_FREE_PROC;
    struct proc_struct *proc = alloc_proc();
    if (proc == NULL) return -E_NO_MEM;
    int ret = setup_kstack(proc);
    if (ret != 0) goto fail_proc;
    if ((ret = copy_mm(clone_flags, proc)) != 0) goto fail_stack;
    copy_thread(proc, stack, tf);
    proc->parent = current;
    bool intr_flag;
    local_intr_save(intr_flag);
    proc->pid = get_pid();
    hash_proc(proc);
    set_links(proc); // 同时维护进程列表、兄弟关系和全局数量。
    wakeup_proc(proc);
    local_intr_restore(intr_flag);
    return proc->pid;
fail_stack:
    put_kstack(proc);
fail_proc:
    kfree(proc);
    return ret;
}


int do_yield(void)
{
    current->need_resched = 1;
    return 0;
}

int do_kill(int pid)
{
    bool intr_flag;
    local_intr_save(intr_flag);
    struct proc_struct *proc = find_proc(pid);
    if (proc == NULL || proc == idleproc || proc == initproc ||
        proc->state == PROC_ZOMBIE || (proc->flags & PF_EXITING)) {
        local_intr_restore(intr_flag);
        return -E_INVAL;
    }
    proc->flags |= PF_EXITING;
    if (proc->state == PROC_SLEEPING && (proc->wait_state & WT_INTERRUPTED)) {
        wakeup_proc(proc);
    }
    local_intr_restore(intr_flag);
    return 0;
}

int do_exit(int error_code)
{
    if (current == idleproc || current == initproc) {
        panic("idle or init process cannot exit");
    }
    struct mm_struct *mm = current->mm;
    if (mm != NULL) {
        uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                               (boot_pgdir_pa >> RISCV_PGSHIFT);
        asm volatile("csrw satp, %0" :: "r"(satp_value) : "memory");
        flush_tlb();
        if (mm_count_dec(mm) == 0) {
            exit_mmap(mm);
            put_pgdir(mm);
            mm_destroy(mm);
        }
        current->mm = NULL;
        current->pgdir = boot_pgdir_pa;
    }
    bool intr_flag;
    local_intr_save(intr_flag);
    current->state = PROC_ZOMBIE;
    current->exit_code = error_code;
    if (current->parent != NULL && current->parent->wait_state == WT_CHILD) {
        wakeup_proc(current->parent);
    }
    while (current->cptr != NULL) {
        struct proc_struct *child = current->cptr;
        current->cptr = child->optr;
        if (current->cptr != NULL) current->cptr->yptr = NULL;
        child->parent = initproc;
        child->yptr = NULL;
        child->optr = initproc->cptr;
        if (child->optr != NULL) child->optr->yptr = child;
        initproc->cptr = child;
        if (child->state == PROC_ZOMBIE && initproc->wait_state == WT_CHILD) {
            wakeup_proc(initproc);
        }
    }
    local_intr_restore(intr_flag);
    schedule();
    panic("zombie process resumed");
}

int do_wait(int pid, int *code_store)
{
    // 2411061：占位区外集成修复，负 PID 没有匹配子进程，与课程接口约定一致。
    if (pid < 0) return -E_BAD_PROC;
    if (code_store != NULL && current->mm != NULL &&
        !user_mem_check(current->mm, (uintptr_t)code_store, sizeof(int), 1)) {
        return -E_INVAL;
    }
repeat: ; // 2411061：C99 标签必须修饰语句，不能直接接变量声明。
    bool intr_flag;
    bool has_child = 0;
    struct proc_struct *proc = NULL;
    local_intr_save(intr_flag);
    if (pid != 0) {
        proc = find_proc(pid);
        if (proc == NULL || proc->parent != current) {
            local_intr_restore(intr_flag);
            return -E_BAD_PROC;
        }
        has_child = 1;
    } else {
        for (proc = current->cptr; proc != NULL; proc = proc->optr) {
            has_child = 1;
            if (proc->state == PROC_ZOMBIE) break;
        }
    }
    if (!has_child) {
        local_intr_restore(intr_flag);
        return -E_BAD_PROC;
    }
    if (proc != NULL && proc->state == PROC_ZOMBIE) {
        int exit_code = proc->exit_code;
        unhash_proc(proc);
        remove_links(proc);
        local_intr_restore(intr_flag);
        // 2411061：占位区外修复，内核回写也必须经过 A 的 COW 分裂检查。
        if (code_store != NULL && !copy_to_user(current->mm, code_store,
                                               &exit_code, sizeof(exit_code))) {
            put_kstack(proc);
            kfree(proc);
            return -E_INVAL;
        }
        put_kstack(proc);
        kfree(proc);
        return 0;
    }
    current->state = PROC_SLEEPING;
    current->wait_state = WT_CHILD;
    local_intr_restore(intr_flag);
    schedule();
    if (current->flags & PF_EXITING) return -E_KILLED;
    goto repeat;
}


#define __KERNEL_EXECVE(name, binary, size) ({           \
    cprintf("kernel_execve: pid = %d, name = \"%s\".\n", \
            current->pid, name);                         \
    kernel_execve(name, binary, (size_t)(size));         \
})

#define KERNEL_EXECVE(x) ({                                    \
    extern unsigned char _binary_obj___user_##x##_out_start[], \
        _binary_obj___user_##x##_out_size[];                   \
    __KERNEL_EXECVE(#x, _binary_obj___user_##x##_out_start,    \
                    _binary_obj___user_##x##_out_size);        \
})

#define __KERNEL_EXECVE2(x, xstart, xsize) ({   \
    extern unsigned char xstart[], xsize[];     \
    __KERNEL_EXECVE(#x, xstart, (size_t)xsize); \
})

#define KERNEL_EXECVE2(x, xstart, xsize) __KERNEL_EXECVE2(x, xstart, xsize)


int do_execve(const char *name, size_t len, unsigned char *binary, size_t size)
{
    if (name == NULL || binary == NULL || size == 0) return -E_INVAL;
    bool had_user_mm = current->mm != NULL;
    char local_name[PROC_NAME_LEN + 1];
    memset(local_name, 0, sizeof(local_name));
    size_t n = len < PROC_NAME_LEN ? len : PROC_NAME_LEN;
    if (current->mm != NULL && !copy_from_user(current->mm, local_name, name, n, 0))
        return -E_INVAL;
    if (current->mm == NULL) memcpy(local_name, name, n);
    unsigned char *image = binary;
    if (current->mm != NULL) {
        image = kmalloc(size);
        if (image == NULL) return -E_NO_MEM;
        if (!copy_from_user(current->mm, image, binary, size, 0)) {
            kfree(image);
            return -E_INVAL;
        }
        struct mm_struct *old = current->mm;
        uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                               (boot_pgdir_pa >> RISCV_PGSHIFT);
        asm volatile("csrw satp, %0" :: "r"(satp_value) : "memory");
        flush_tlb();
        current->mm = NULL;
        current->pgdir = boot_pgdir_pa;
        if (mm_count_dec(old) == 0) {
            exit_mmap(old);
            put_pgdir(old);
            mm_destroy(old);
        }
    }
    int ret = load_icode(image, size);
    if (image != binary) kfree(image);
    if (ret == 0) set_proc_name(current, local_name);
    // 2411061：旧用户映像已销毁时装载失败必须退出，不能恢复到已释放的用户 PC。
    if (ret != 0 && had_user_mm) do_exit(ret);
    return ret;
}

int kernel_execve(const char *name, unsigned char *binary, size_t size)
{
    int ret = do_execve(name, strlen(name), binary, size);
    if (ret == 0) forkrets(current->tf);
    return ret;
}

static int user_main(void *arg)
{
#ifdef TEST
    // 2411061：占位区外接通框架 build-*/make grade 的程序选择，默认仍运行 hello。
    int ret = KERNEL_EXECVE2(TEST, TESTSTART, TESTSIZE);
#else
    int ret = KERNEL_EXECVE(hello);
#endif
    panic("user_main: exec failed: %d", ret);
}

static int init_main(void *arg)
{
    kmalloc_trim(); // 2411061：在相同的“堆空闲页已归还”条件下比较资源基线。
    size_t free_before = nr_free_pages(); // 2411061：记录启动子进程前的真实资源基线。
    int count_before = nr_process;
    int pid = kernel_thread(user_main, NULL, 0);
    if (pid <= 0) panic("cannot create user process: %d", pid);
    while (do_wait(0, NULL) == 0) { }
    // 2411061：占位区外收尾修复，init 不退出；先核对回收，再进入调试监控器。
    assert(current->cptr == NULL && nr_process == count_before);
    kmalloc_trim();
    assert(nr_free_pages() == free_before);
    cprintf("all user-mode processes have quit.\n");
    cprintf("init check memory pass.\n");
    panic("init: all user processes have exited");
}

void proc_init(void)
{
    list_init(&proc_list);
    for (int i = 0; i < HASH_LIST_SIZE; i++) list_init(&hash_list[i]);
    if ((idleproc = alloc_proc()) == NULL) panic("cannot allocate idle process");
    idleproc->pid = 0;
    idleproc->state = PROC_RUNNABLE;
    idleproc->kstack = (uintptr_t)bootstack;
    idleproc->need_resched = 1;
    set_proc_name(idleproc, "idle");
    current = idleproc;
    nr_process = 1;
    int pid = kernel_thread(init_main, NULL, 0);
    if (pid <= 0 || (initproc = find_proc(pid)) == NULL)
        panic("cannot create init process");
    set_proc_name(initproc, "init");
}

void cpu_idle(void)
{
    while (1) {
        if (current->need_resched) schedule();
    }
}

void proc_run(struct proc_struct *proc)
{
    if (proc == current) return;
    bool intr_flag;
    local_intr_save(intr_flag);
    struct proc_struct *prev = current;
    current = proc;
    uintptr_t satp_value = ((uintptr_t)SATP_MODE_SV39 << 60) |
                           (proc->pgdir >> RISCV_PGSHIFT);
    asm volatile("csrw satp, %0" :: "r"(satp_value) : "memory");
    flush_tlb();
    switch_to(&prev->context, &proc->context);
    local_intr_restore(intr_flag);
}



