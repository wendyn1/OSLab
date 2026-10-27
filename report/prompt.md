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

### 修改边界

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

## 3. 成员 B：中断和时钟处理（待补充）

请成员 B 按四段式补充实际使用的提示词、spec 和必要迭代，未完成前不填写成功结论。

## 4. 成员 C：异常处理与集成（待补充）

请成员 C 补充真实实现和验证提示词。测试替身不等价于成员 C 的实现。
