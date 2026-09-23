# Lab1 提示词汇总

本文件汇总 Lab1 环境搭建、代码阅读、调试验证和报告整理过程中使用的提示词。提示词经过逐步补充上下文和验证要求，以减少只给出理论答案而不核对实际运行结果的问题。

## 1. 环境搭建

```text
这是部署大模型和搭建实验环境的操作文档。请阅读文档，检查电脑现有环境，
完成操作系统实验所需的 AI 编程工具、RISC-V 交叉编译器、QEMU、Git、
Make 和调试工具的安装，并实际验证编译和 OpenSBI 启动。
```

## 2. Lab1 代码检查

```text
这是 Lab1 的实验文档和实验代码。请读取课程网站及 lab1.zip，区分课程文档
中的实验要求和我的请求。请检查目录结构、阅读 Makefile、entry.S、init.c 和
链接脚本，在搭好的环境中编译、运行并确认还需要完成哪些练习和报告内容。
```

## 3. 构建和启动兼容性

```text
请检查提供的 Lab1 Makefile 与当前 QEMU/OpenSBI 的兼容性。先编译并运行，
根据启动日志判断 OpenSBI 是否获得了 0x80200000 作为下一阶段入口。
如果原启动参数无法进入内核，请做最小化的 Makefile 适配，并验证 make、
make qemu 和 QEMU+GDB 调试链路。不要修改 kern/ 和 libs/ 下的课程源代码。
```

## 4. 练习1：入口代码分析

```text
请阅读 Lab1 的 kern/init/entry.S，结合 RISC-V 调用约定和内核启动流程，
解释 la sp, bootstacktop 与 tail kern_init 分别完成什么操作、目的是什么。
请区分伪指令与实际机器指令，并结合 objdump 或 GDB 结果验证 SP 和 RA 的变化。
```

## 5. 练习1：进一步核对

```text
请根据链接脚本、memlayout.h 和实际 GDB 输出计算 bootstack 与 bootstacktop
之间的距离，确认启动栈大小。说明为什么栈顶使用高地址、执行 tail 后 RA 是否
改变，以及为什么 kern_init 不需要返回到 kern_entry。不要仅复述概念。
```

## 6. 练习2：启动流程调试

```text
请使用 QEMU 和 GDB 跟踪提供的 RISC-V Lab1，从 PC=0x1000 开始，
依次在 0x80000000 和 0x80200000 设置硬件执行断点。记录复位代码、
OpenSBI 入口和 kern_entry 的关键寄存器、特权级及反汇编结果；继续单步
验证 la sp, bootstacktop 和 tail kern_init。结论必须来自实际调试日志。
```

## 7. 练习2：监视点问题核对

```text
在 GDB 连接 QEMU 且 CPU 尚停在 0x1000 时，先检查 0x80200000 是否已经
包含内核入口指令。判断内核镜像是在 CPU 运行前由 QEMU 装载，还是继续执行后
由 OpenSBI 写入。解释为什么写监视点和 0x80200000 的执行断点不能互相替代。
```

## 8. 测试与报告

```text
请根据本机真实的 build.log、qemu.log 和 gdb.log 整理 Lab1 实验报告。
报告要回答全部练习，说明整体逻辑、核心模块、实验知识点与 OS 原理的联系和差异、
本实验未涉及的重要 OS 知识，并明确记录测试范围和限制。不得虚构 make grade 通过；
如果课程包缺少 grade.sh，应如实说明，并使用编译、QEMU 输出和 GDB 记录作为证据。
```

## 9. 按课程模板整理交付物

```text
请按照课程提供的“实验报告模板.md”整理最终报告，并严格生成以下目录：
code/ 放实现后的完整代码；report/report.md 为实验报告；report/prompt.md 汇总
本实验所有提示词；report/images/ 放报告引用的测试截图。报告填写三位成员的
基本信息和分工，删除所有模板占位符，检查 Markdown 图片链接能够正常解析。
```
