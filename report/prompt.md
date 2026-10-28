# Lab3 提示词汇总

## 需求规格（Spec）

### 已有条件

1. 当前为 RV64，REGBYTES=8，LOAD/STORE 展开为 ld/sd。
2. SAVE_ALL 已提供且保持不变，在当前内核栈分配 36×8=288 字节。
3. trapframe 的前 32 个槽位对应 x0～x31，后四个依次是 status、epc、badvaddr、cause。
4. 第 2 号槽位保存分配现场之前的 sp，而当前 sp 指向整个现场起始地址。
5. void trap(struct trapframe *tf) 遵循 RISC-V ABI；处理函数可以修改 tf->epc，以确定返回位置。
6. 当前测试与实现范围是框架提供的内核态 Trap 路径，不增加用户栈切换或浮点现场保存。

### RESTORE_ALL

输入：sp 指向有效、与 SAVE_ALL 一致的 Trap frame。输出：恢复返回所需的 CSR 与通用寄存器，sp 回到保存值，为紧随其后的 sret 做好准备。

- 从偏移 256、264 读取 status、epc，分别写入 sstatus、sepc。
- 用 t0、t1 暂存 CSR 内容，之后从现场恢复它们原来的值。
- 恢复 x1、x3～x31；x0 恒为零，不写回；最后从偏移 16 恢复 x2/sp。
- 不自行修改 epc、不强制改变 SPP、不把诊断用 cause/badvaddr 机械写回。
- 不将当前 sp 再加 288 代替读取保存槽位；保持恢复接口与实际保存状态一致。

### __alltraps

- 保留已有 SAVE_ALL 调用。
- 执行 mv a0, sp，将当前 Trap frame 地址作为第一个 C 参数。
- 执行 call trap，允许汇编器与链接器进行正常的调用展开和松弛。
- C 函数返回后顺序进入 __trapret，由 RESTORE_ALL 和 sret 返回。
- 不增加无关栈帧。原 sp 满足 16 字节对齐时，减去 288 后仍满足 ABI 对齐。

### 修改边界（成员 A 当时的独立任务）

正式源码只修改 kern/trap/trapentry.S 的两个待填位置。保留 SAVE_ALL、trap.h、trap.c、测试与评分脚本。将对应 YOUR CODE 替换为 2414166。

### 验收

1. 汇编目标编译成功，反汇编显示偏移和恢复顺序正确。
2. 临时副本中，16 位、32 位断点分别在 SIE=0、SIE=1 条件下各执行一次。
3. GDB 在触发前保存全部 32 个 GPR 槽位值，在 trap C 入口检查现场、参数、288 字节差值和对齐。
4. 在 sret 前验证所有可写 GPR 恢复、x0 仍为零、sepc 和 sstatus 正确；在返回地址再次验证 GPR、PC 和 SIE。
5. 正式模块二保持空缺；隔离测试不宣称完整 Lab3 评分通过。

## Prompt 整理

```text
[PROMPT]
在当前 Lab3 框架中完成成员 A 的模块一，只实现
kern/trap/trapentry.S 中 RESTORE_ALL 和 __alltraps 的待填部分。

[RELY]
SAVE_ALL、struct trapframe、REGBYTES、LOAD/STORE 和 trap() 接口已提供。
RV64 上现场为 36 个 8 字节槽位；x2 槽位保存 Trap 前的 sp。
CSR 槽位依次是 sstatus、sepc、异常附加信息和 scause。

[GUARANTEE]
不修改 SAVE_ALL、结构体、trap() 签名及模块二或评分脚本。
保留任务注释并将 YOUR CODE 替换为 2414166。
使用临时寄存器恢复 CSR 后，恢复这些临时寄存器自身的保存值。
最后恢复 sp，不自行递增 epc，不强制切换到用户态。

[SPECIFICATION]
1. 从现有布局恢复 sstatus、sepc 以及 x1、x3～x31，最后恢复 x2。
2. SAVE_ALL 后通过 a0 传入当前现场地址，正常调用 trap()。
3. 返回后进入 __trapret，完成恢复并执行 sret。
4. 核对现场布局、栈对齐、CSR 和调用约定，并提供实现说明。
```

## 验证与迭代记录

验证脚本采用独立临时副本，加入明确标记的异常处理替身，按实际编码跳过 2/4 字节断点。测试汇编先保存调用者的 callee-saved 寄存器和 ra，测试结束后恢复，避免测试函数自身违反 ABI。

真实迭代发生在验证工具：GDB 中 sp 位运算需要显式整数转换；直接入口断点未可靠命中，因此改为在 trap 精确入口检查 SAVE_ALL 后的状态；QEMU 4.1.1 的 SPIE 返回行为与指导书不同，核对官方源码后按版本记录。详见 [调试记录](evidence/member-a/debug-record.md)。


## 2. 2414166-滕鑫-模块一：独立验证设计

以下为本轮实际测试设计的可复用需求整理，与代码实现提示词分开记录。

```text
[PROMPT]
为模块一建立可复现的隔离验证，不修改正式模块二或课程评分脚本。

[RELY]
模块一已实现，模块二仍为占位；WSL 中提供 GCC、GDB、QEMU。

[GUARANTEE]
仅在临时副本添加最小断点处理替身；探针自身遵守 ABI。
记录全部真实输出、失败与修复；不把替身当作完整实验答案。

[SPECIFICATION]
对 16/32 位断点与 SIE=0/1 的四个组合，比较进入前的 GPR、
SAVE_ALL 后的现场及 C 参数、sret 前 CSR、返回后的 GPR/PC/SIE。
保存构建、反汇编、GDB、运行日志；记录模拟器版本差异。
```

实现脚本：[verify_member_a.py](../code/lab3/tools/verify_member_a.py)。

## 3. 2410721-何熹淳：中断和时钟处理

```text
[PROMPT]
修改 kern/trap/trap.c，补全 interrupt_handler(struct trapframe *tf)。
处理软件中断、时钟中断、外部中断和未知中断。Supervisor Timer 分支
必须形成持续时钟：设置下一次事件、增加 ticks、每 100 次输出一次，
输出十次后通过 SBI 关机。保留已有接口和输出风格，不用循环模拟计数。

[RELY]
- tf->cause：scause 保存值，最高位是中断标志，低位是 cause code
- __riscv_xlen：当前 RISC-V 位数
- IRQ_U/S/H/M_SOFT、IRQ_U/S/H/M_TIMER、IRQ_U/S/H/M_EXT
- clock_set_next_event()：设置下一次 SBI 定时事件
- volatile size_t ticks：累计时钟中断次数
- TICK_NUM：100；print_ticks()：输出一次计数结果
- sbi_shutdown()：请求 OpenSBI 关闭 QEMU
- print_trapframe(tf)：输出未知 Trap 的现场

[GUARANTEE]
void interrupt_handler(struct trapframe *tf);

[SPECIFICATION]
Pre-Condition:
- tf 非空，tf->cause 保存本次中断的 scause
- 时钟和 Supervisor 中断已在初始化阶段开启

Post-Condition:
- 已知中断进入对应分支，不破坏 trapframe
- Supervisor Timer 已安排下一次事件并使 ticks 恰好增加 1
- 未知中断输出低位编号和现场信息

Case 1（Supervisor Timer）:
- 清除 scause 最高位后编号为 IRQ_S_TIMER
- 先调用 clock_set_next_event()，再增加 ticks
- ticks 每达到 TICK_NUM 的整数倍调用 print_ticks()
- 独立记录输出次数，达到 10 次时输出结束信息并调用 sbi_shutdown()

Case 2（其他已知中断）:
- 按 U/S/H/M 和 software/timer/external 分类并输出类型
- 不修改 epc，中断返回后继续被打断位置

Case 3（未知中断）:
- 输出 Unknown interrupt: cause <低位编号>
- 调用 print_trapframe(tf)

Requirements:
- 中断号必须先清除与 __riscv_xlen 对应的最高位
- SBI 定时器是一次性事件，每次 Supervisor Timer 中断都必须重设
- 计数必须来自真实中断，不能用循环直接修改 ticks
```

### 测试提示词

```text
[PROMPT]
运行课程 make grade 测试 Lab3，中断部分必须覆盖 Supervisor software
interrupt、未知编号 15、持续时钟到 200 ticks，以及多次 Trap 返回。

[RELY]
- Makefile 的 grade 目标和 tools/grade.sh
- QEMU/OpenSBI 实际运行结果

[GUARANTEE]
- 不修改评分断言制造通过结果
- 保存测试输出到 report/evidence/lab3_grade.log

[SPECIFICATION]
- 持续时钟项应得到 PASS（40/40）
- 完整三项测试总分应为 100/100
```

## 4. 2411061-牛雨萱：异常处理与集成


### 需求规格（Spec）

- 前置条件：框架为 RV64GC 内核态路径，tf 是有效现场；对于两类可恢复异常，epc 指向可读、至少两字节对齐的指令。
- 非法指令输出 `Illegal instruction at 0x%08x\n`；断点输出 `Breakpoint at 0x%08x\n`。
- 从 epc 读取首个 16 位半字。当前实验的 16/32 位编码中，低两位不等于 3 则跳过 2 字节，否则跳过 4 字节。不以 cause 判断固定长度。
- 只更改这两类异常的 epc，其他现场字段保持原值；未知异常调用 print_trapframe，不猜测恢复地址。
- 集成核对 Lab2 的 page_init、Best-Fit、启动映射和中断保护，复测原有评分，并单独验证真实 16/32 位异常和十次时钟输出后的关机。
- 不扩展到不可读指令地址、48 位及更长指令、用户栈切换或完整缺页恢复。

### 最终提示词

```text
[PROMPT]
完成 C 的异常处理、Lab2 依赖检查、最终集成与报告补全。

[RELY]
现有 SAVE_ALL、RESTORE_ALL、trap_dispatch、struct trapframe、
CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT、print_trapframe，
以及原有 make grade 和 WSL 中的 RISC-V/QEMU 环境。

[GUARANTEE]
保留已有正确实现与成员署名，仅在 exception_handler 内作必要调整。
不更改 trap.c 的其他函数、SAVE_ALL、结构体及评分断言。
记录真实发现和失败，不把已有代码说成本轮从零生成，不虚构测试。

[SPECIFICATION]
1. 两类异常按框架格式输出，根据首半字编码将 epc 增加 2 或 4。
2. 其他异常输出现场；两类已处理异常不更改现场的其他字段。
3. 在临时副本中触发四类真实异常，确认返回后继续执行。
4. 断言精确 EPC 增量和现场不变量，覆盖其他中断及兜底分支。
5. 运行原有评分，验证 Lab2 自检、持续时钟和十次输出后正常关机。
```

### 实际迭代记录

开始核验时 exception_handler 已有两类异常、2/4 字节判定及兜底。本轮保留算法，增加只读指针和适用范围注释，并新增 tools/verify_member_c.py。在临时副本中注入测试，正式初始化流程不添加测试调用。

首次 WSL 命令的 PATH 展开包含 Windows 路径空格和括号，shell 解析失败；改为 `env PATH=...` 显式传参。随后首次评分因 grade.sh 的 CRLF 换行在 sh 中报错；保留失败日志，将脚本转换为 LF，通过 .gitattributes 固定脚本换行，评分断言不变。

复现命令与最终结果见报告 5.4，证据保存在 [member-c](evidence/member-c/summary.txt)。
