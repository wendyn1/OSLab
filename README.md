# OSLab · Lab4：进程管理

本分支使用与 Lab3 一致的 `code/` + `report/` 仓库布局。指导书中的实验代码目录 `labcodes/lab4`，在本仓库中对应 `code/lab4/`；构建、调试和评分均从该目录执行。

## 目录结构

```text
OSLab-lab4/
├── README.md                    # 目录、运行方法与协作说明
├── .gitattributes               # 文本文件统一使用 LF
├── .gitignore                   # 忽略构建产物和本机配置
├── code/
│   └── lab4/
│       ├── Makefile             # 课程构建、运行和评分入口
│       ├── CMakeLists.txt       # 初始代码附带配置
│       ├── kern/                # 内核源码
│       │   ├── debug/
│       │   ├── driver/
│       │   ├── init/
│       │   ├── libs/
│       │   ├── mm/              # 成员一：物理内存与页映射
│       │   ├── process/         # 成员二、三：创建与切换
│       │   ├── schedule/        # 成员三：调度
│       │   ├── sync/
│       │   └── trap/
│       ├── libs/                # 公共库和 RISC-V 定义
│       └── tools/               # 课程脚本、链接脚本及成员一测试
└── report/
    ├── report.md                # 唯一的总实验报告，三人共同补充
    ├── prompt.md                # spec / prompt 汇总
    ├── images/                  # 报告截图
    └── evidence/
        └── member1/
            ├── full-build.log
            ├── member1-build.log
            └── member1-qemu.log
```

构建生成的 `obj/`、`bin/` 位于 `code/lab4/`，已忽略，不提交。验证日志属于实验报告证据，保留并提交。

## 报告入口

- [实验总报告](report/report.md)
- [提示词与规格记录](report/prompt.md)
- [成员一 QEMU 验证结果](report/evidence/member1/member1-qemu.log)

成员一的实现说明、Challenge 2、调试过程和测试结果均已写入总报告，不再单独维护个人报告。

## 成员一独立验证

负责人：2414166 滕鑫。当前开发分支：`lab4-memory`。

从仓库根目录在 WSL 中执行，工具链路径按本机安装位置调整：

```bash
export PATH=/opt/riscv/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin:$PATH
python3 code/lab4/tools/test_member1.py
```

脚本在临时副本中构建测试内核，日志统一写入 `report/evidence/member1/`。不会改动正式启动入口或课程测试。已验证页表与 VMA 自检、课程 PMM 检查、分配失败回滚、引用计数、幂等删除、活动映射与 TLB、异常返回和连续时钟中断。

## 完整构建与课程评分

成员二、三完成后，在 WSL 中执行：

```bash
cd code/lab4
make
make qemu
# 退出 QEMU 后执行：
make grade
```

目前缺少成员二、三的 `proc_init`、`cpu_idle` 等实现，完整内核尚不能链接。成员一独立检查 PASS 不代表完整 Lab4 评分通过。

## 与成员二、三对接

- 功能模块二：`kern/process/proc.c` 中的 `alloc_proc`、`proc_init`、`kernel_thread`、`do_fork`、`copy_thread`、`copy_mm`。
- 功能模块三：`proc.c` 中的 `cpu_idle`、`proc_run`，`kern/schedule/sched.c` 中的 `schedule`，`kern/process/switch.S` 中的 `switch_to`。
- 两位成员分别补充总报告、提示词和自己的测试证据；Challenge 1 由成员三填写。
- 物理页管理导出框架既有的 `default_pmm_manager`，内部使用迁移的 Best-Fit，不依赖额外的 `best_fit_pmm.h`。
- `page_remove` 不释放空的中间页表，地址空间销毁时由调用者回收；同页重映射不增加净引用，异页替换会减少旧页引用。
- 保留课程 `get_pte` 接口和权限约定，本次不实现大页拆分或多核同步。
- Lab3 测试专用的定时自动关机不迁移到 Lab4。
- 代码目录迁移后，请从 `code/lab4/` 继续开发；成员二、三的源码内容未因目录整理而修改。

## Git 提交

本轮目录整理尚未自动提交或推送。确认 `git status` 后，在当前分支提交代码、报告和目录移动，再向 `lab4` 发起 Pull Request。不要把构建产物加入仓库。
