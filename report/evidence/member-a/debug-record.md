# 成员 A 现场恢复调试记录

日期：2026-10-27。实际环境版本见 environment.txt。

## 执行方法

正式工作树为桌面 OSLab-lab3-work，分支 lab3-member-a。单独执行 make obj/kern/trap/trapentry.o 成功。

独立脚本 verify_member_a.py 将 code/lab3 复制到 /tmp/lab3-member-a-*/lab3，忽略构建产物，在副本中添加仅用于测试的异常处理函数和 ABI 合规的寄存器探针。未执行完整 make grade，因为成员 B/C 尚未实现。

从仓库根目录在 WSL 复现：

```bash
export PATH="/opt/riscv/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin:$PATH"
python3 code/lab3/tools/verify_member_a.py code/lab3 /tmp/member-a-validation
cat /tmp/member-a-validation/gdb.log
cat /tmp/member-a-validation/boot.log
```

输出目录记录编译、启动、反汇编、GDB 命令、环境版本和临时副本位置。临时源码中有模块二替身，不能用作提交版本。脚本预期模块二仍有原始占位；B/C 实现后应改用集成验证。

## 本次成功观测

四次 Trap 均通过全部断言，正常关机，脚本退出码为 0。

| 项目 | 实测值 |
| --- | --- |
| 触发前 sp | 0xffffffffc0204f80 |
| trap() 入口 a0/sp | 0xffffffffc0204e60 |
| 两者差值 | 0x120 = 288 |
| 16 位断点地址 → 返回位置 | 0xffffffffc0200140 → 0xffffffffc0200142 |
| 32 位断点地址 → 返回位置 | 0xffffffffc0200144 → 0xffffffffc0200148 |
| SIE=0：触发前 / sret 前 / 返回后 sstatus | 0x8000000000006000 / 0x8000000000006100 / 0x8000000000006000 |
| SIE=1：触发前 / sret 前 / 返回后 sstatus | 0x8000000000006002 / 0x8000000000006120 / 0x8000000000006002 |

每次均核对 Trap frame 中 x0～x31 的槽位，包括原 sp、ra、gp、tp、a0；核对 status、epc、badvaddr、cause 的值；在 sret 前及返回后分别比较全部 GPR。x0 是恒零检查，其他 31 个寄存器是值保持检查。返回后的 SIE 与触发前一致。

最终 GDB 输出：MEMBER_A_GDB_PASS: 4 lifecycles, 16/32-bit breakpoints, SIE=0/1。
最终内核输出：MEMBER_A_RUNTIME_PASS: four breakpoint returns。

## 真实遇到的问题

### GDB 指针位运算

初版脚本使用 ($sp & 15) 检查对齐，GDB 报 Argument to arithmetic operation not a number or boolean。改为 ((unsigned long)$sp & 15) 后正常。这是调试表达式问题，不是内核恢复失败。首次错误日志保留为 gdb-first-attempt.log。

### Trap 入口断点未命中

本次 QEMU/GDB 组合从触发指令处继续后，直接设在 __alltraps 的断点未按预期触发，导致保存入口状态的便利变量没有值。最终改在 *trap（C 函数第一条指令）检查：此时 SAVE_ALL 已完成，而处理函数尚未修改现场。通过现场与 CSR 的对应关系验证进入状态，不声称直接观察到 __alltraps 第一条指令。

### QEMU 4.1.1 的 SPIE 行为

初版按指导书预期 sret 后 SPIE=1，但实际得到 SPIE=0。核对 [QEMU v4.1.1 helper_sret 源码](https://github.com/qemu/qemu/blob/v4.1.1/target/riscv/op_helper.c#L68) 后确认，该版本显式把 SPIE 设为 0，并把 SPP 清零。测试仅对识别出的 4.1.1 版本采用这一已知行为；其他版本按 SPIE=1 检查。正式代码不增加补丁来改变模拟器行为。

恢复前 sstatus 精确等于保存值、SIE 恢复结果、返回位置和全部 GPR 的断言仍保留。这一区分避免把模拟器差异误诊为 RESTORE_ALL 错误。

## 验证边界

验证覆盖内核 S 态 Trap 的进入/返回、四次重复异常、两种指令长度、两种 SIE 状态。gp/tp 保留有效原值后比较，不刻意写入破坏 C 环境的常量。没有验证用户态栈切换、浮点/向量上下文、真正的嵌套 Trap、持续时钟中断或正式模块二实现。后续合并 B/C 后必须运行完整 make grade。
