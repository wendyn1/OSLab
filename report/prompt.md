# Lab4 提示词与规格记录

## 成员一：2414166 滕鑫

负责功能模块一、Lab2/Lab3 前置整合和 Challenge 2。以下按 Lab3 的四段式格式整理本次实现约束，不作为逐字对话记录。详细前置条件、后置条件、实现分析与验证见 [总报告](report.md)。

```text
[PROMPT]
完成 Lab4 功能模块一：虚拟内存页操作功能，以及 Lab2/Lab3 前置代码整合。
负责人为 2414166 滕鑫，新增实现保留 LAB4 function1 标注。

[RELY]
现有 pmm.c、pmm.h、mmu.h、Page、get_pte、pte_create、page2ppn、
pte2page、引用计数、页分配和 TLB 接口；小组已经完成的 Lab3 代码；
WSL 的 RISC-V 工具链、QEMU 和课程 tools/test_lab4.c 中的 PMM 检查。

[GUARANTEE]
不修改成员二、三、正式 kern_init 入口或课程测试断言。
保留迁移代码的原作者注释，适配 Lab4 接口，不整文件覆盖旧框架。
同页重映射不释放页面、不增加净引用；无映射删除不分配页表。
失败返回 -E_NO_MEM，不泄漏本次已分配的中间页表页。
记录实际代码检查、构建和测试结果，区分独立验证与完整实验验收。

[SPECIFICATION]
page_insert 使用 get_pte(create=1)，区分新建、同页重映射、异页替换，
写入调用者要求的权限，保持 PTE、引用计数、TLB 同步。
page_remove 使用 get_pte(create=0)，无映射幂等返回，有映射则清除、
失效 TLB、减少引用，仅在引用降至零时释放物理页。
get_pte 下层分配失败时只回滚本次新建的上层页表，保留已有父表。
迁移 page_init、Best-Fit、启动修正、Trap 入口与恢复及事件处理；
不迁移 Lab3 测试专用的自动关机行为。
在临时副本验证课程 PMM 检查、分配失败、引用计数、幂等删除、
实际访存/TLB 更新、异常返回和连续时钟中断，保存构建与运行日志。
```

Challenge 2 的分析要求：结合 Sv32、Sv39、Sv48 的页表层数、索引宽度、PTE 大小和页内偏移，说明 `get_pte()` 两段代码的相似原因；讨论合并查找和分配的优缺点及拆分方案，区分本实验 4 KiB 页路径与硬件大页支持。

## 成员二：进程创建及初始化功能

```text
[PROMPT]
完成 proc.c 中模块二：alloc_proc、proc_init、kernel_thread、do_fork、
copy_thread、copy_mm。只实现内核线程创建，不修改模块一的页映射和模块三的调度。

[RELY]
proc_struct/context/trapframe 的现有布局；setup_kstack/put_kstack、
get_pid/hash_proc/find_proc、bootstack、boot_pgdir_pa、local_intr_save/restore；
kernel_thread_entry、forkret、forkrets 与后续 switch_to 的调用链。

[GUARANTEE]
内核线程的 PCB、栈、PID、父进程、链表和哈希索引一致；
失败时释放已取得的资源；模块三接入后首次切换能进入 forkret。

[SPECIFICATION]
alloc_proc 初始化为 PROC_UNINIT、pid=-1、mm=NULL、内核页表，链表节点有效。
proc_init 创建 PID 0 idleproc（使用 bootstack），current 指向它，
再创建 PID 1 initproc，二者为 PROC_RUNNABLE。
kernel_thread 用 s0/s1 传函数和参数，epc 指向 kernel_thread_entry。
do_fork 依次分配 PCB、内核栈、复制/共享地址空间、设置现场，
在中断保护区分配 PID、加入索引，成功返回子 PID。
copy_thread 设置子线程 a0=0、context.ra=forkret、context.sp=tf，
保留内核线程的 SPP。copy_mm 当前仅支持 mm=NULL 的内核线程。
```

此前编译检查：`make obj/kern/process/proc.o` 成功。曾发现清除 SPP 会使内核线程首次返回的特权级错误，已删除该操作。当时完整动态验证等待模块三合并；本轮发现并修正默认 sp 和 SIE 问题后，原有创建/调度测试与补充动态验证均通过，详见成员三记录及总报告。

## 成员三：进程调度与 Challenge 1

**负责人：2411061 牛雨萱。** 

```text
[PROMPT]
根据当前 Lab4 手册核验成员一、二完成情况，
完成模块三 cpu_idle、schedule、proc_run、switch_to，解答 Challenge 1，
运行完整构建、原有课程评分和补充验证。

[RELY]
现有 proc_struct/context、proc_list/current/idleproc、PROC_RUNNABLE、
local_intr_save/restore、lsatp、flush_tlb、REGBYTES/LOAD/STORE，
以及成员二准备的 context.ra/sp 和 TrapFrame 首次运行链路。

[GUARANTEE]
不改变 context 布局和公共函数签名，不改课程评分断言。
切换 current、页表、执行现场时关中断，最终恢复进入前的中断状态。
保留成员一、二原有成果和署名，必要集成修复单独记录。
不把目标文件编译通过当作首次运行成功，不虚构原始生成过程。

[SPECIFICATION]
从当前线程之后轮转选择 runnable，空链表/全阻塞退回 idle，维护 runs。
proc_run 写入正确 RV64 Sv39 satp 并执行 sfence.vma。
switch_to 保存恢复 ra/sp/s0-s11，ret 到目标现场。
核对新线程的内核栈、SPP/SPIE/SIE，说明 TrapFrame 与 context 的区别。
验证原有 PMM/进程创建/调度评分，再检查 idle 回退、轮转顺序、
多次切换寄存器和中断状态、失败清理及切换后连续时钟。
解释 Challenge 1 的 CSR、嵌套临界区和单核适用范围。
```
