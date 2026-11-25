# Lab5 提示词与规格记录

小组成员：2414166-滕鑫（A）、2410721-何熹淳（B）、2411061-牛雨萱（C）。以最终分工图为准。以下按 Lab0.5 的四段式模板规范整理；A/B 已有代码的规格为本轮依据实际实现核验后的整理，不虚构为原始逐字对话。调试结果以 report.md 和原始日志为准。

## 成员 A：用户态系统调用

```text
[PROMPT]
任务：在 kern/trap/trap.c、trapentry.S、kern/syscall/syscall.c 和 user/libs/syscall.[ch]
建立用户态请求、系统调用分发、双栈切换和异常返回能力；pmm.c 提供用户页表显示。
操作要求：必须修改实际文件，保留原有代码和作者标记，仅补全对应标记位置。
输出要求：使用以下真实上下文和接口，提供代码及真实验证，不引入无关系统调用。

[RELY]
trapframe 含 gpr/status/epc/tval/cause；a0 为课程调用号，a1-a5 为参数。
CAUSE_USER_ECALL、SSTATUS_SPP、SYS_*、current->tf、current->mm、PF_EXITING。
do_exit/do_fork/do_wait/do_execve/do_yield/do_kill、cow_prepare_user_write、
user_mem_check、cputchar、get_pte、print_trapframe。

[GUARANTEE]
static void interrupt_handler(struct trapframe *tf);
void exception_handler(struct trapframe *tf);
void syscall(void);
static int sys_exit(uint64_t arg[]);
static int sys_fork(uint64_t arg[]);
static int sys_wait(uint64_t arg[]);
static int sys_exec(uint64_t arg[]);
static int sys_yield(uint64_t arg[]);
static int sys_kill(uint64_t arg[]);
static int sys_getpid(uint64_t arg[]);
static int sys_putc(uint64_t arg[]);
static int sys_pgdir(uint64_t arg[]);
void print_pgdir(void);
汇编交付：RESTORE_ALL、__alltraps 内的 C 接口调用。
用户库交付（以下为独立用户ELF中的函数，不与内核static包装混淆）：
int sys_exit(int64_t error_code);
int sys_fork(void);
int sys_wait(int64_t pid, int *store);
int sys_exec(const char *name, size_t len, const void *binary, size_t size);
int sys_yield(void);
int sys_kill(int64_t pid);
int sys_getpid(void);
int sys_putc(int64_t c);
int sys_pgdir(void);
允许 static 内部辅助函数，不改变公共 ABI。

[SPECIFICATION]
interrupt_handler
Pre-Condition: tf 是有效中断现场，时钟设备已初始化。
Post-Condition: 已识别中断得到相应处理，时钟仍可持续，未知类型有诊断。
Case 1: 时钟更新真实计数并请求调度；其他来源按框架提示。
Requirements: 不将 Lab3 的定次关机迁入正式内核。

exception_handler
Pre-Condition: tf 保存本次异常，current 如非空则其 tf 指向本现场。
Post-Condition: 用户 ecall 按 ABI 分发，正常返回位置为下一条指令。
Case 1: COW 写异常可修复时保持故障指令位置，允许重试。
Case 2: 不可恢复用户异常退出当前进程，内核异常输出诊断并停止。
Requirements: 保留课程评分可链接的处理接口，不用 static 隐藏该符号。

RESTORE_ALL / __alltraps
Pre-Condition: 现场布局为36个机器字，保存逻辑和结构体一致。
Post-Condition: C 处理函数取得正确现场指针，返回恢复正确特权级、栈和寄存器。
Case 1: 返回 U 态时 sscratch 提供下一次用户 Trap 的内核栈；返回 S 态时为零。
Requirements: 不提前恢复 sp，不在现场恢复未完成时开启中断。

syscall
Pre-Condition: current->tf 有效，a0 为完整调用号。
Post-Condition: 有效调用执行一次，结果保存在 tf->gpr.a0。
Case 1: 超范围或空槽返回 -E_INVAL，不访问越界表项。

sys_exit
Pre-Condition: 参数按课程 ABI 保存。
Post-Condition: 将退出码交给 do_exit，成功退出不再返回用户执行流。
sys_fork
Pre-Condition: 当前现场和用户 sp 有效。
Post-Condition: 普通 fork 父进程得到 PID，子进程从保存现场返回零。
sys_wait
Pre-Condition: pid 和可空的退出码指针由用户提供。
Post-Condition: 参数合法时交给 do_wait；非空目的区须通过用户写入与 COW 检查。
sys_exec
Pre-Condition: 用户提供名称、长度、ELF范围。
Post-Condition: 不合法范围返回错误，合法请求交给 do_execve。
sys_yield
Pre-Condition: 当前进程可运行。
Post-Condition: 交给 do_yield，请求重新调度。
sys_kill
Pre-Condition: 参数含目标PID。
Post-Condition: 返回 do_kill 对目标状态的处理结果。
sys_getpid
Pre-Condition: current 有效。
Post-Condition: 返回当前 PID。
sys_putc
Pre-Condition: 参数含待输出字符。
Post-Condition: 输出一字符并返回零。
sys_pgdir
Pre-Condition: current 可以查询。
Post-Condition: 调用页表显示接口，返回零。
print_pgdir
Pre-Condition: 系统已建立基本页表机制。
Post-Condition: 有用户地址空间则显示映射及权限，没有则安全返回。

用户 sys_* 封装
Pre-Condition: 调用者位于用户态，参数符合相应声明。
Post-Condition: 以课程寄存器约定发起 ecall，并按 C 接口返回结果。
Requirements: 不读取不存在的变参，不以64位写入破坏32位返回变量；不改为Linux a7 ABI。
```

## 成员 A：双重 GDB 分支

```text
[PROMPT]
任务：通过客户机及宿主 GDB 跟踪同一次 ecall/sret，解释 QEMU 4.1.1 的相关处理。
操作要求：运行真实调试并保存断点和寄存器，不修改内核行为来伪造观测。
输出要求：交付两侧日志、TCG 与执行 helper 的解释及真实排查记录。
[RELY]
客户机 RISC-V GDB、宿主 GDB、带符号的 QEMU、用户 ELF、trapframe。
trans_privileged.inc.c、op_helper.c、cpu_helper.c 中实际对应源码。
[GUARANTEE]
交付客户机 ecall 前/内核 syscall/用户返回点记录，宿主 ecall/sret 对应记录。
此任务不新增内核公共函数，调试命令和产物必须可复查。
[SPECIFICATION]
双重调试产物
Pre-Condition: 用户程序可运行，QEMU和内核调试符号可用。
Post-Condition: 日志能关联同次调用的PC、原因码、权限、参数和返回值。
Case 1: 用户符号未加载，显式加载用户ELF或使用明确的受控用户PC。
Case 2: QEMU无符号，选择匹配版本的调试构建。
Requirements: 区分调试异常与真实ecall，区分TCG翻译与helper执行，不虚构观测。
```

## 成员 A：COW Challenge

```text
[PROMPT]
任务：在 cow.[ch]、写缺页入口、copy_to_user 以及 user/cowtest.c 提供写时复制能力；
与 C 的普通深复制基线通过 dup_mmap 的显式构建开关分开。
操作要求：修改真实项目文件；标记外扩展单列报告，不删除普通 fork 实现。
输出要求：提供正常复制/单引用恢复/真正只读拒绝/回收的状态机和测试。
[RELY]
PTE_U/W/V、软件位0x100、VM_WRITE/STACK、Page.ref、mm_struct.pgdir、
page_insert、get_pte、tlb_invalidate、user_mem_check、local_intr_save/restore。
[GUARANTEE]
int cow_copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end);
int cow_resolve_write(struct mm_struct *mm, uintptr_t addr);
bool cow_prepare_user_write(struct mm_struct *mm, uintptr_t addr, size_t len);
bool copy_to_user(struct mm_struct *mm, void *dst, const void *src, size_t len);
用户用例：int main(void)，位于 user/cowtest.c。
允许 static 辅助函数；保持 CLONE_VM 整个 mm 共享语义。
[SPECIFICATION]
cow_copy_range
Pre-Condition: 源与目标不同，目标未发布，区间页对齐且位于用户范围。
Post-Condition: 子映射引用建立；原可写页在父子处只读且标记COW。
Case 1: 真正只读页可共享但不能获得COW写授权。
Case 2: 失败保留可清理的子映射，调用者销毁未发布mm。
cow_resolve_write
Pre-Condition: 给出待写地址，可检查VMA和PTE。
Post-Condition: 成功后当前进程有可写映射，不影响其他持有者的数据。
Case 1: 引用为一，恢复写权限；引用大于一，获得独立数据页。
Case 2: 真正只读、非COW、保护页或资源不足返回错误，不放宽非法权限。
Requirements: 单hart中保护映射和引用状态，TLB与权限同步，修复后重试原指令。
cow_prepare_user_write
Pre-Condition: 内核准备写一段用户缓冲区。
Post-Condition: 全范围逻辑可写且映射存在，必要COW页先被分裂。
Case 1: 跨页逐页检查，不能只检查首地址。
copy_to_user
Pre-Condition: 源内核缓冲区有效，目标用户范围可校验。
Post-Condition: 可写检查和必要分裂成功才复制，失败不向非法目的区写入。
用户cowtest main
Pre-Condition: fork/wait/exit/yield可用。
Post-Condition: 父先写、子先写及wait退出码回写均保持隔离，并有明确成功标记。
```

## 成员 B：创建和装载首个用户进程（含 do_wait）

```text
[PROMPT]
任务：在 kern/process/proc.c 建立内核线程到用户ELF装载、首次进入和等待回收链路。
操作要求：必须修改实际文件，保留模块一与模块三接口，异常处置不伪造成功。
输出要求：完成以下接口并解释ELF预加载时机，保存原有make/qemu/grade证据。
[RELY]
proc_struct、trapframe、ELF header/proghdr、USTACKTOP/USTACKSIZE、PTE_U/R/W/X。
kmalloc/kfree、mm_create/mm_map、setup_pgdir/put_pgdir、pgdir_alloc_page、
copy_thread/do_fork、copy_from_user/copy_to_user、set_links/remove_links、schedule。
[GUARANTEE]
static struct proc_struct *alloc_proc(void);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
static int init_main(void *arg);
static int user_main(void *arg);
int kernel_execve(const char *name, unsigned char *binary, size_t size);
int do_execve(const char *name, size_t len, unsigned char *binary, size_t size);
static int load_icode(unsigned char *binary, size_t size);
int do_wait(int pid, int *code_store);
仅允许同模块static辅助函数，不更改公开声明或课程断言。
[SPECIFICATION]
alloc_proc
Pre-Condition: kmalloc已初始化。
Post-Condition: 成功返回安全空白PCB，含UNINIT、pid=-1、内核根表及合法链表节点。
Case 1: 资源不足返回NULL，无半登记对象。
kernel_thread
Pre-Condition: 函数和参数可用于内核执行。
Post-Condition: 为函数与参数建立首次现场并返回新PID或负错误码。
Requirements: SPP/SPIE为一、SIE为零，内核栈必须有效。
init_main
Pre-Condition: 当前为init线程，创建机制可用。
Post-Condition: 启动首个用户执行实体，等待子代退出并核对资源回收，不允许init走普通退出。
Case 1: 无子进程后进入明确的实验收尾路径；资源不平衡必须触发断言。
user_main
Pre-Condition: 用户ELF已作为二进制链接进内核。
Post-Condition: 选择默认hello或框架TEST指定程序，成功后不返回旧内核线程函数。
kernel_execve
Pre-Condition: 当前内核线程有有效初始tf，镜像范围有效。
Post-Condition: 成功经统一Trap返回路径进入U态；失败返回错误。
do_execve
Pre-Condition: 当前进程及名称/镜像参数可校验。
Post-Condition: 成功后运行新映像；旧用户空间按引用所有权回收。
Case 1: 原映像中的用户参数必须在旧映像销毁前保存。
Case 2: 初期失败返回错误；若旧用户映像已销毁而新装载失败，终止进程，禁止返回已释放的用户PC。
load_icode
Pre-Condition: ELF数据范围可读，current有可用于用户返回的tf。
Post-Condition: ELF段及栈建立，文件内容正确，BSS和新用户栈清零，用户入口/sp/返回特权级有效。
Case 1: 格式/范围错误或内存不足，回收本次未发布映像及页表。
Requirements: 用户页权限体现段属性，内核页不因装载而变为用户可访问。
do_wait
Pre-Condition: pid可选指定子代或任意子代，退出码指针可空。
Post-Condition: 收取僵尸退出码并回收PCB和内核栈，或等待合法子代后重试。
Case 1: 非子代/没有子代/负PID返回-E_BAD_PROC；非法目的区返回-E_INVAL。
Case 2: 子代未退出则睡眠等待，不丢失唤醒；被终止则返回被杀错误。
Requirements: 用户退出码写回使用copy_to_user，兼容COW；不释放正在使用的当前栈。
```

## 成员 B：其余系统调用内核实现

```text
[PROMPT]
任务：在 kern/process/proc.c 实现退出、主动让出和终止指定进程的生命周期控制。
操作要求：必须修改真实文件，和do_wait及进程树接口保持一致，保留既有逻辑。
输出要求：按以下规格交付代码和退出/等待/唤醒真实测试，禁止只返回固定成功值。
[RELY]
current/idleproc/initproc、PROC_ZOMBIE、PF_EXITING、WT_CHILD、WT_INTERRUPTED。
mm_count_dec、exit_mmap、put_pgdir、mm_destroy、wakeup_proc、schedule、进程树指针。
[GUARANTEE]
int do_exit(int error_code);
int do_yield(void);
int do_kill(int pid);
允许模块内部static辅助函数，不改公共接口。
[SPECIFICATION]
do_exit
Pre-Condition: 当前进程有效。
Post-Condition: 普通进程释放最后持有的用户空间，保留退出码并进入僵尸态，随后不再运行。
Case 1: idle/init退出为内核错误；共享mm只在最后引用释放时销毁。
Case 2: 等待父进程被唤醒，孤儿转交init，已退出孤儿能被等待回收。
Requirements: 不释放自身当前内核栈和PCB；交由父进程wait最终回收。
do_yield
Pre-Condition: current有效。
Post-Condition: 设置重调度请求，返回零；调度由统一返回路径处理。
do_kill
Pre-Condition: 给出目标PID。
Post-Condition: 合法目标记录退出意图，必要时唤醒可中断睡眠者。
Case 1: 无效/保护进程/僵尸/已请求退出目标返回-E_INVAL。
Requirements: 状态检查和更新在适当临界区内，目标在安全退出点终止。
```

## 成员 C：普通 fork 基线与集成

```text
[PROMPT]
任务：在 kern/process/proc.c、kern/mm/vmm.c、kern/mm/pmm.c 实现普通fork的完整复制，
并与A的系统调用、B的装载和退出协作。保留普通深复制为默认，COW为显式扩展构建。
操作要求：必须修改实际文件，只在lab5 function3 YOUR CODE对应区补全，署名2411061，
新增中文注释；确有必要的标记外修复，先核验实际阻塞并在报告逐项列出。
输出要求：交付能运行的普通fork基线、父子返回值和隔离验证、失败回滚及真实课程评分。
[RELY]
CLONE_VM、PROC_UNINIT/RUNNABLE、proc_struct.parent/cptr/optr/yptr、mm_count。
alloc_proc、setup_kstack/put_kstack、setup_pgdir/put_pgdir、forkret、wakeup_proc、
get_pid/hash_proc/set_links、mm_create/mm_destroy/exit_mmap、lock_mm/unlock_mm、
vma_create/insert_vma_struct、get_pte/page_insert、alloc_page/free_page/page2kva。
PTE_USER=(PTE_R|PTE_W|PTE_X|PTE_U|PTE_V)，PGSIZE，USER_ACCESS。
[GUARANTEE]
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
static void copy_thread(struct proc_struct *proc, uintptr_t stack, struct trapframe *tf);
int dup_mmap(struct mm_struct *to, struct mm_struct *from);
int copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end, bool share);
static void lab5_copy_selfcheck(void); // 仅在 LAB5_COPY_SELFTEST 构建中存在。
允许同模块static辅助函数。默认不调用COW路径，不改评分断言。
[SPECIFICATION]
do_fork
Pre-Condition: current与tf有效，内存及调度机制已初始化。
Post-Condition: 成功返回子PID，子现场a0=0，可调度且父子关系/哈希/列表/数量一致。
Case 1: 进程数达到上限返回-E_NO_FREE_PROC。
Case 2: PCB/栈/mm资源不足返回错误，已取得资源按所有权归还，不发布半初始化子进程。
Requirements: 发布关系和唤醒在临界区内；继承正确用户返回PC及栈。
copy_mm
Pre-Condition: 新PCB已有内核栈，尚未发布；父mm可查询。
Post-Condition: 子拥有正确mm引用及根表地址，失败无本次地址空间泄漏。
Case 1: 父mm为空，保留内核线程路径。
Case 2: CLONE_VM共享整个mm并增加mm_count。
Case 3: 普通fork创建独立mm/根表及VMA和数据映像，失败清理部分映像。
Requirements: 复制期间保护源mm；仅成功后增加目标mm持有者引用。
copy_thread
Pre-Condition: 子栈已分配且tf有效。
Post-Condition: 子栈持有独立现场，a0为零，sp有效，context恢复后进入forkret。
Case 1: 显式用户stack保留该值；无显式stack的内核线程使用合法新栈。
dup_mmap
Pre-Condition: to/from不同且有效，目标为未发布的新地址空间，调用者持有源mm锁。
Post-Condition: VMA区间和标志保持，已存在页的复制符合当前构建模式。
Case 1: 默认逐页独立复制；显式LAB5_COW构建委托A的COW接口。
Case 2: VMA或页分配失败返回错误，已登记VMA足以由调用者统一清理。
copy_range
Pre-Condition: 不同有效页表，区间页对齐且合法用户范围，目标区间为空。
Post-Condition: 默认目标有效页与源内容相同、物理页不同，权限一致；源映射不改变。
Case 1: 源空洞跳过；share显式为真时共享物理页并维护映射引用。
Case 2: 资源不足返回错误，未映射的新页由本函数归还，已映射页由调用者销毁。
Requirements: 不把Page描述符当数据页，不把深复制当作COW验证证据。
lab5_copy_selfcheck
Pre-Condition: 内存管理可用；测试宏显式开启，测试映像不对外发布。
Post-Condition: 检查当前构建模式的物理页、内容、权限、引用和空洞状态，释放测试对象。
Case 1: 普通分支断言物理独立；COW分支断言共享、分裂和单引用恢复。
Case 2: COW测试受控注入只读授权错误后立即恢复，安全接口必须拒绝伪造标记升级。
Requirements: 不将该测试解释为Linux原始竞争漏洞的等价复现。
```

## 集成修复：前置切换和完整资源回收

```text
[PROMPT]
任务：修复实际构建/评分证据确认的标记外缺陷，完成LAB4切换迁移、目录销毁和SLOB缓存回收。
操作要求：必须修改真实文件，只作必要修复，加2411061中文注释，报告逐项列出标记外位置。
输出要求：保留原评分断言、失败日志和资源检查，不使用空替身或放宽断言制造通过。
[RELY]
proc_list/current/idleproc、context的14个机器字、local_intr_save/restore、proc_run。
pgdir/pde/pte、NPTEENTRY/NPDEENTRY、free_page、SLOB arena/slobfree链及页边界。
[GUARANTEE]
void schedule(void);
void switch_to(struct context *from, struct context *to);
void exit_range(pde_t *pgdir, uintptr_t start, uintptr_t end);
void kmalloc_trim(void);
此外模块A/B已列出的 exception_handler/do_wait/user_main/init_main/load_icode/do_execve
按对应规格作必要修复，接口不变。配置交付仅固定shell的LF换行，不改评分逻辑。
[SPECIFICATION]
schedule
Pre-Condition: current/idle及链表有效。
Post-Condition: 选中可运行线程或idle，关键状态切换不被本hart中断破坏，返回后恢复原使能。
switch_to
Pre-Condition: from/to有效，目标现场和栈已准备。
Post-Condition: ra/sp/s0-s11按context布局完成保存恢复，ret进入目标现场。
exit_range
Pre-Condition: 区间页对齐且合法，数据映射已按销毁流程撤销。
Post-Condition: 回收覆盖路径上的空表，但绝不丢弃仍含有效子项的上层目录。
Case 1: 区间不包含整张目录，仍以整张表是否为空作为父表回收依据。
kmalloc_trim
Pre-Condition: SLOB可用，当前可进入本hart临界区。
Post-Condition: 完整空闲页归还物理分配器，其余可用块链和活跃对象不变。
Case 1: 空闲块跨页，保留非整页前后缀；没有整页可回收则不改变分配状态。
Requirements: 不在新页刚加入供slob_alloc使用时自动立即回收；仅在显式收尾检查点执行。
```

### 本轮规格与实现修订记录

- 两张分工图不是同一版本；最终以A=模块一/双GDB/COW，B=模块二含wait及模块四，C=模块三为准。
- 开始核验时C的四个标记为空，copy_thread辅助函数也未迁入；A有独立日志，B有主体但未联合验收。
- 编译定位到do_wait标签后声明、原评分定位到异常函数static符号；修复均单列于报告。
- 源码还缺schedule/switch_to的Lab4迁移，必须补齐才能链接；不得用空替身宣称完成。
- 所有提示词按任务、操作要求、输出要求、可信依赖、接口清单及逐函数Pre/Post组织；Case描述条件与结果，不用伪代码序列代替行为要求。
