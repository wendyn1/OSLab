# Lab5 模块二交接（2410721 何熹淳）

## 已实现

`code/lab5/kern/process/proc.c` 中完成 PCB 初始化和内核线程入口、首个用户进程建立与 ELF 加载、`do_execve`、`do_wait`，以及 `do_exit`、`do_yield`、`do_kill`。`init_main` 创建 `user_main`，后者将内置的 `hello` ELF 加载到独立用户地址空间，并通过 `forkrets` 返回到 U 态执行。ELF 的可加载段按虚拟地址映射，页先清零再复制文件内容，用户栈在 `USTACKTOP` 下建立。

退出时释放用户地址空间、把当前进程置为僵尸态、唤醒等待的父进程并把子进程过继给 `initproc`；`do_wait` 回收僵尸子进程的内核栈和 PCB。`do_yield` 设置重新调度标志；`do_kill` 标记目标退出并唤醒可中断睡眠中的目标。

## 接口与集成

- 模块三需要补齐 `do_fork`、`copy_thread`、`copy_mm`、`dup_mmap`、`copy_range`。本模块的 `kernel_thread` 和 `proc_init` 依赖 `do_fork` 创建执行流。
- Lab4 的 `schedule`、`switch_to` 仍需从已完成的 Lab4 集成；模块二的 `cpu_idle`、`proc_run` 已写入本文件。
- 模块一的系统调用分发和 Trap 已存在；用户 `exec` 路径经 `do_execve`，内核首次启动路径经 `kernel_execve`。

## 验证结果与待办

在 WSL 中执行 `make obj/kern/process/proc.o` 成功。整仓 `make` 目前先在原有的 `kern/mm/kmalloc.c:92` 遇到 `kva2page` 参数类型警告（构建把警告当错误），尚未完成链接和 QEMU/grade。请在三人模块集成后修正该类型、运行 `make`、`make qemu`、`make grade`，并以实际输出更新总报告和截图；当前不得写成已通过评分。
