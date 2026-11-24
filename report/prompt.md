# Lab5 提示词与规格记录

小组成员：2411061-牛雨萱、2410721-何熹淳、2414166-滕鑫。

以下按 [Lab05 标准提示词结构](http://oslab.mobisys.top/lab2026/_book/lab0.5/3_prompt_structure.html) 记录各成员的规格和提示词。模块归属、实现过程和验证结果见 [小组实验报告](report.md)。

## 成员一：2414166 滕鑫

负责功能模块一、前置整合、双重 GDB 和 COW Challenge。

**功能模块一：用户态系统调用**

```text
[PROMPT]
任务：修改 kern/trap/trap.c、trapentry.S、kern/syscall/syscall.c、
user/libs/syscall.[ch]，打通 U 态 ecall 到内核分发及 sret。适配 Lab2/Lab4
的页表与物理内存前置代码，并补齐 kern/mm/pmm.c 的用户页表显示。
操作要求：直接修改实际项目文件，保留模板的 lab5 标注，将本人所负责
位置的 YOUR CODE 改为 2414166。模块二、三、四通过既有 do_* 接口交接。
输出要求：提供可交叉编译的代码和可复核的运行证据，区分临时验证与全组评分。

[RELY]
struct trapframe 的 gpr、status、epc、tval、cause，struct proc_struct 的
tf、pid、mm、flags、need_resched，sscratch、SSTATUS_SPP、CAUSE_USER_ECALL。
libs/unistd.h 的 SYS_* 编号，do_exit、do_fork、do_wait、do_execve、
do_yield、do_kill 的 proc.h 接口，user_mem_check、cputchar、get_pte。

[GUARANTEE]
static void interrupt_handler(struct trapframe *tf);
static void exception_handler(struct trapframe *tf);
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
汇编交付 RESTORE_ALL 和 __alltraps 到 trap 的调用路径。

[SPECIFICATION]
exception_handler
Pre-Condition: trap 已保存现场，当前进程的 tf 指向本次现场。
Post-Condition: U 态 ecall 分发一次，保存的返回地址移到下一条指令。
Case 1: 用户触发其他不可恢复异常，终止当前用户进程。
Case 2: 内核触发不可恢复异常，输出现场并停止。
Requirements: COW 写缺页修复后重试原指令。

interrupt_handler / RESTORE_ALL
Pre-Condition: 进入中断时寄存器已保存在内核栈的 36 个字宽槽位。
Post-Condition: 时钟中断重新安排下一次时钟事件。恢复路径恢复 CSR 和通用寄存器。
Case 1: 返回 U 态，预先保存下次进入所需的内核栈指针，最后恢复用户 sp。
Case 2: 返回 S 态，sscratch 保持零，恢复原内核 sp。

syscall / sys_*
Pre-Condition: 当前进程的 trapframe 完整，a0 是调用号，a1 至 a5 为实参。
Post-Condition: 有效调用分发一次，结果经 a0 返回。非法编号或空槽返回 -E_INVAL。
Case 1: exit、fork、yield、kill 转交对应 do_*，fork 使用当前用户 sp 和现场。
Case 2: wait 的退出码指针可空，非空时须可写。exec 的名称和 ELF 范围须可读。
Case 3: getpid 返回当前 PID，putc 输出一字符，pgdir 显示当前用户映射。
Requirements: 不截断调用号，不读取未提供的可变参数，返回值宽度与 C 接口一致。

print_pgdir
Pre-Condition: 可从 current 取得用户地址空间。
Post-Condition: 输出已映射用户页的虚拟地址与权限。没有地址空间时直接返回。
```

**双重 GDB 分支**

```text
[PROMPT]
任务：用匹配本机 QEMU 版本的带符号构建和 RISC-V GDB 跟踪一次完整 ecall/sret。
操作要求：在 WSL 临时副本运行真实调试，记录两侧实际断点、观察值和失败原因。
输出要求：解释实际命中的 QEMU 源码和 TCG，与其他实验的占位结果明确区分。

[RELY]
RISC-V GDB、宿主 GDB、QEMU gdbstub、trapframe 的 cause/epc、
QEMU 4.1.1 的 trans_privileged.inc.c、op_helper.c 和 cpu_helper.c。

[GUARANTEE]
提交两侧 GDB 记录，覆盖 ecall、内核 syscall 入口和 sret 后返回用户态。

[SPECIFICATION]
Pre-Condition: 使用能进入 U 态的内核和可解析宿主符号的 QEMU。
Post-Condition: 两侧日志能关联同一条 ecall 的 PC、原因码、返回 PC 和返回值。
Case 1: 只加载了内核符号，使用用户 ELF 符号或受控夹具的已知用户 PC。
Case 2: QEMU 已剥离符号，找到同版本的带调试信息构建后重试。
Requirements: 区分 TCG 生成和运行，保存可复现脚本、实际值和 AI 排查记录。
```

**Challenge：写时复制**

```text
[PROMPT]
任务：实际修改 cow.[ch]、Trap 写缺页入口、copy_to_user，并提供 cowtest.c，
在单 hart Lab05 下实现共享、分裂和释放。保留成员 C 的普通 fork 基线，
从已建立 VMA 的私有复制路径接入 COW。
操作要求：根据真实 PTE、引用计数和用户访问规则修改工程。
输出要求：提供状态转换说明，测试正常隔离、只读保护和退出后引用释放。

[RELY]
PTE_U、PTE_W、PTE_SOFT，mm_struct.pgdir、VM_WRITE、VM_STACK，
get_pte、page_insert、page_ref、alloc_page、free_page、tlb_invalidate、
user_mem_check、local_intr_save 和 local_intr_restore。

[GUARANTEE]
int cow_copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end);
int cow_resolve_write(struct mm_struct *mm, uintptr_t addr);
bool cow_prepare_user_write(struct mm_struct *mm, uintptr_t addr, size_t len);
bool copy_to_user(struct mm_struct *mm, void *dst, const void *src, size_t len);
用户态交付 cowtest.c，报告给出完整 fork 接入点和失败清理约定。

[SPECIFICATION]
cow_copy_range
Pre-Condition: 目标地址空间未对外运行，源、目标不同且区间页对齐。
Post-Condition: 每个有效用户映射获得一个子映射引用。
Case 1: 原页可写，子映射先建立，再去掉父映射写权限，双方标为 COW。
Case 2: 原页本来只读，两边保持只读且不设置 COW。
Case 3: 分配失败，由调用方销毁未发布的子映射。父进程可用单引用路径恢复写入。

cow_resolve_write
Pre-Condition: 给出了写入地址。访问必须通过范围、VMA 和 PTE 验证。
Post-Condition: 成功后故障进程拥有可写私页，原物理页仍供持有者读取。
Case 1: 引用为一，只恢复页权限。
Case 2: 多个引用，复制一页并重建当前映射。
Case 3: 不可写、非 COW 或内存不足，返回错误，不恢复原只读页的写权限。
Requirements: 在单 hart 下保护状态转换，权限变化时同步 TLB。

cow_prepare_user_write / copy_to_user
Pre-Condition: 内核准备写到一段用户地址。
Post-Condition: 检查目标范围和每个映射，先分裂确认为 COW 的页，再写数据。
Requirements: 覆盖跨页范围，拒绝未映射、真正只读或命中栈保护页的目的区间。
```

## 成员二：用户程序装载与进程控制（负责人待认领）

**功能模块二：创建加载第一个用户进程功能**

> 待对应成员按 Lab0.5 的四段式补写。这一节预留给模块二。

```text
[PROMPT]
（填写任务、目标文件、操作要求和输出要求）

[RELY]
（填写真实宏、结构体和依赖函数）

[GUARANTEE]
（列出本模块接口及交付约束）

[SPECIFICATION]
（按函数写 Pre-Condition、Post-Condition、Case 和必要的 Requirements）
```

**功能模块四：其余系统调用功能**

> 待对应成员按 Lab0.5 的四段式补写。这一节预留给模块四。

```text
[PROMPT]
（填写任务、目标文件、操作要求和输出要求）

[RELY]
（填写真实宏、结构体和依赖函数）

[GUARANTEE]
（列出本模块接口及交付约束）

[SPECIFICATION]
（按函数写 Pre-Condition、Post-Condition、Case 和必要的 Requirements）
```

> 待填模块二和模块四的实际编译、调试结果及规格修订记录。

## 成员三：用户进程复制（负责人待认领）

**功能模块三：复制用户进程功能**

> 待对应成员按 Lab0.5 的四段式补写。这一节预留给模块三。

```text
[PROMPT]
（填写任务、目标文件、操作要求和输出要求）

[RELY]
（填写真实宏、结构体和依赖函数）

[GUARANTEE]
（列出本模块接口及交付约束）

[SPECIFICATION]
（按函数写 Pre-Condition、Post-Condition、Case 和必要的 Requirements）
```

> 待填模块三的实际编译、调试结果及规格修订记录。
