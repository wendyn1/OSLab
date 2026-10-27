# Lab3 提示词汇总

## 中断与时钟模块（2410721-何熹淳）

```text
[PROMPT]
修改 kern/trap/trap.c，补全 interrupt_handler(struct trapframe *tf)。
需要处理软件中断、时钟中断、外部中断以及未知中断。Supervisor Timer
分支要形成持续时钟：设置下一次事件、增加 ticks、每 100 次输出一次，
输出十次后通过 SBI 关机。只修改本任务相关代码，保留原有接口和输出风格。

[RELY]
- tf->cause：scause 的保存值，最高位是中断标志，低位是 cause code
- __riscv_xlen：当前 RISC-V 位数
- IRQ_U_SOFT、IRQ_S_SOFT、IRQ_H_SOFT、IRQ_M_SOFT
- IRQ_U_TIMER、IRQ_S_TIMER、IRQ_H_TIMER、IRQ_M_TIMER
- IRQ_U_EXT、IRQ_S_EXT、IRQ_H_EXT、IRQ_M_EXT
- clock_set_next_event()：设置下一次 SBI 定时事件
- volatile size_t ticks：累计时钟中断次数
- TICK_NUM：100
- print_ticks()：输出一次计数结果
- sbi_shutdown()：请求 OpenSBI 关闭 QEMU
- print_trapframe(tf)：输出未知 Trap 的现场

[GUARANTEE]
void interrupt_handler(struct trapframe *tf);

[SPECIFICATION]
Pre-Condition:
- tf 非空，tf->cause 保存了本次中断的 scause
- 时钟和 Supervisor 中断已经在初始化阶段开启

Post-Condition:
- 已知中断进入对应分支，不破坏 trapframe
- Supervisor Timer 已安排下一次事件并使 ticks 恰好增加 1
- 未知中断给出编号和现场信息

Case 1（Supervisor Timer）:
- 清除 scause 最高位后编号为 IRQ_S_TIMER
- 先调用 clock_set_next_event()，再增加 ticks
- ticks 每达到 TICK_NUM 的整数倍调用 print_ticks()
- 独立记录输出次数，达到 10 次时输出结束信息并调用 sbi_shutdown()

Case 2（其他已知中断）:
- 按 U/S/H/M 和 software/timer/external 分类
- 输出清楚的中断类型，不修改 epc

Case 3（未知中断）:
- 输出 Unknown interrupt: cause <低位编号>
- 调用 print_trapframe(tf)

Requirements:
- 中断号必须先清除与 __riscv_xlen 对应的最高位
- SBI 定时器是一次性事件，每次 Supervisor Timer 中断都必须重设
- 不把 epc 前移，中断返回后应继续执行被打断位置
- 不用循环模拟 ticks，计数必须来自真实中断
```

## Trap 入口与恢复模块

```text
[PROMPT]
补全 kern/trap/trapentry.S 的 __alltraps 和 RESTORE_ALL，使入口保存的
寄存器布局与 struct trapframe 完全一致。把 trapframe 指针放入 a0 调用
trap，返回后恢复 CSR 和通用寄存器，最后执行 sret。

[RELY]
- SAVE_ALL 宏及 struct trapframe 字段顺序
- sstatus、sepc、stval、scause CSR
- trap(struct trapframe *tf)

[GUARANTEE]
__alltraps
RESTORE_ALL

[SPECIFICATION]
- 必须完整恢复被中断前的通用寄存器和 sepc/sstatus
- sp 最后恢复，恢复过程中始终以当前 trapframe 为基址
- a0 传入当前 sp，C 函数返回后仍从该 trapframe 恢复
```

## 异常处理模块

```text
[PROMPT]
补全 exception_handler(struct trapframe *tf)，处理非法指令和断点异常。
根据 epc 所指指令低两位判断指令是 16 位还是 32 位，更新 epc 后返回；
其他异常打印完整 trapframe。

[RELY]
- CAUSE_ILLEGAL_INSTRUCTION、CAUSE_BREAKPOINT
- tf->epc、tf->cause
- RISC-V 指令低两位编码规则
- print_trapframe(tf)

[GUARANTEE]
void exception_handler(struct trapframe *tf);

[SPECIFICATION]
- 指令低两位为 0b11 时 epc += 4，否则 epc += 2
- 已处理异常返回后不能再次执行同一条异常指令
- 未知异常保留并输出现场信息
```

## 测试提示词

```text
[PROMPT]
使用课程提供的 make grade 测试 Lab3，不通过时根据第一处失败定位问题。
测试必须覆盖：Trap 入口和寄存器恢复、断点返回、非法指令 2/4 字节长度、
Supervisor software interrupt、未知编号 15、持续时钟到 200 ticks。

[RELY]
- 项目 Makefile 的 grade 目标
- tools/grade.sh 与课程注入测试
- QEMU/OpenSBI 实际运行输出

[GUARANTEE]
- 保存完整测试输出
- 不修改评分断言来制造通过结果

[SPECIFICATION]
- 三项测试必须分别得到 35/35、25/25、40/40
- 总分必须为 100/100
- 测试日志保存至 report/evidence/lab3_grade.log
```
