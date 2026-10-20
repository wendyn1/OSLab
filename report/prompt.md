# Lab2 提示词汇总

以下提示词统一采用课程示例中的 `[PROMPT]`、`[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 四段格式。代码生成与测试设计分别记录，不将测试要求混入实现提示词。

## 1. 功能模块一：实现 `page_init()`

```text
[PROMPT]
直接修改 kern/mm/pmm.c，实现 page_init()。根据设备树给出的物理内存
基址和大小建立 Page 描述符数组，并将内核及描述符数组之后的完整空闲页
注册给当前 pmm_manager。

[RELY]
- get_memory_base()/get_memory_size() 返回 DTB 内存信息。
- end 是链接脚本提供的内核结束虚拟地址。
- PADDR、ROUNDUP、ROUNDDOWN、PGSIZE、SetPageReserved、init_memmap 已提供。

[GUARANTEE]
- 只修改 page_init() 中标有 Lab2 的实现位置，保留其他成员学号。
- 不修改 init_memmap、pa2page、测试函数和评分脚本。
- DTB 信息无效时 panic；不存在完整空闲页时不调用 init_memmap。

[SPECIFICATION]
1. 计算 va_pa_offset、npage 和 pages。
2. 把 [nbase,npage) 的 Page 描述符先标为 reserved。
3. 排除 OpenSBI、内核镜像和 Page 数组占用空间。
4. 所有边界按 PGSIZE 对齐，向 init_memmap 传入描述符和页数。
```

## 2. 功能模块二：实现并接入 Best-Fit

```text
[PROMPT]
直接修改 kern/mm/best_fit_pmm.c 和 kern/mm/pmm.c，参考现有 First-Fit，
实现完整 Best-Fit 物理页管理器并注册到 pmm_manager。

[RELY]
- pmm.h 提供 struct pmm_manager 接口。
- memlayout.h 提供 Page、property 和页面标志。
- list.h 提供双向链表操作；basic_check() 与 best_fit_check() 已提供。

[GUARANTEE]
- 不修改 basic_check()、best_fit_check()、page_init() 和测试断言。
- 空闲链表保持地址递增，相同大小候选选择低地址块。
- 保留 Lab2 注释并将本任务 YOUR CODE 替换为 2414166。

[SPECIFICATION]
1. 实现初始化、空闲区注册、分配、释放、计数及管理器注册。
2. 分配时选择能容纳请求的最小空闲块，必要时拆分。
3. 释放时按地址插回并与前后连续空闲块合并。
4. 在 init_pmm_manager() 中启用 best_fit_pmm_manager。
```

## 3. 分支任务：观察 QEMU 中的 Sv39 地址翻译

```text
[PROMPT]
根据当前 Lab2 源码设计双 GDB 调试流程：宿主 GDB 观察 QEMU 地址翻译，
RISC-V GDB 通过 gdbstub 调试 guest 内核，并整理实际观测记录。

[RELY]
- QEMU 关键函数为 riscv_cpu_tlb_fill()、get_physical_address()。
- guest 关键位置为 kern_init、pmm_init、page_init。
- Sv39 使用 satp、三级 VPN 和 PTE 完成翻译。

[GUARANTEE]
- 所有地址、寄存器值和结论来自实际断点或源码。
- 不把 QEMU 软件 TLB 描述成真实硬件 TLB。
- 记录双 GDB 同时冻结 QEMU 时的冲突与解决办法。

[SPECIFICATION]
解释 address、access_type、mmu_idx、satp、根页表地址、特权级及三级
遍历流程，并保存关键终端截图。
```

## 4. 任务三第一份提示词：生成并接入 Buddy System

```text
[PROMPT]
直接在当前 ucore Lab2 工程中从零实现 Buddy System 物理页分配模块。
新增 kern/mm/buddy_system.c 和 buddy_system.h，定义并注册
buddy_system_pmm_manager，同时在 pmm_init() 中接入隔离自测。

[RELY]
- pmm.h 提供 struct pmm_manager、alloc_pages/free_pages、Page 转换接口。
- memlayout.h 提供 Page、property、PG_property 和 free_area_t。
- list.h 提供双向链表操作。
- 当前主分配器是 Best-Fit，SLUB 测试依赖它，不能被破坏。

[GUARANTEE]
- 不修改 First-Fit、Best-Fit、page_init、SLUB 和课程测试断言。
- 代码适应裸机 C 环境，不使用 libc 动态内存。
- 用 2410721 标记新增代码。
- Buddy 自测必须使用独立页区，结束后清理 Page 状态并完整归还 Best-Fit。

[SPECIFICATION]
1. 每个 order 维护一条空闲链表，order k 表示 2^k 个连续页。
2. init_memmap 将任意连续页区分解成对齐的 2 次幂块。
3. alloc_pages 将请求向上取整到 2 次幂，从更高 order 逐级二分。
4. free_pages 通过相对页号异或计算伙伴；同阶空闲伙伴递归合并。
5. 正确维护 Page.property、PageProperty 和空闲页总数。
6. 提供标准 pmm_manager 注册结构及 buddy_system_self_check() 接口。
```

## 5. 任务三第二份提示词：设计 Buddy System 测试

```text
[PROMPT]
为上一提示词生成的 Buddy System 编写内核态测试函数，并在 QEMU 启动时
执行。测试失败必须触发 assert，成功时打印 buddy_system_check() succeeded!。

[RELY]
- Buddy 将 n 页请求向上取整为最小 2 次幂块。
- 可通过 nr_free_pages 检查分配和归还数量。
- 测试页区由当前 Best-Fit 一次性提供，测试结束后必须归还。

[GUARANTEE]
- 不删除或放宽已有断言，不伪造成功输出。
- 不修改 Best-Fit 和 SLUB 的实现或测试。
- 每次分配都检查非 NULL、块大小、相对位置与空闲页计数。

[SPECIFICATION]
1. 使用 64 页隔离区域初始化 Buddy。
2. 测试 1 页、3 页和 8 页请求，确认 3 页实际占用 4 页。
3. 测试超过可用空间的请求返回 NULL。
4. 释放两个相邻 8 页块后申请 16 页，确认递归合并且起始地址一致。
5. 全部释放后空闲页恢复到 64，归还后 Best-Fit 空闲页数恢复。
6. 与 check_alloc_page 和 slub_check 同时运行，完成回归验证。
```

## 6. Challenge 第一份提示词：生成并接入 SLUB

```text
[PROMPT]
直接在当前 ucore Lab2 中从零实现简化 SLUB 对象分配器。新增 slub.c、
slub.h，并在 pmm_init 完成页级检查后初始化和自测。

[RELY]
- 底层通过 alloc_page/free_page 获取和归还 4 KiB 页。
- page2pa 和 va_pa_offset 可把 Page 转为内核虚拟地址。
- 当前 pmm_manager 为 Best-Fit。

[GUARANTEE]
- 不修改 Best-Fit 测试及断言；使用 2410721 标记 Challenge 代码。
- 不使用宿主 libc；非法指针和重复释放必须触发 assert。
- 所有对象释放后必须把空 slab 整页归还 PMM。

[SPECIFICATION]
1. 建立 8 至 2048 字节的 2 次幂 size class。
2. 每个 slab 占一页，页首保存 magic、cache、inuse、total、freelist。
3. 空闲对象使用对象内嵌单链表，不单独分配描述符。
4. 实现 slub_init、slub_alloc、slub_free；0 字节和超大请求返回 NULL。
```

## 7. Challenge 第二份提示词：设计 SLUB 测试

```text
[PROMPT]
为简化 SLUB 编写 slub_check() 内核测试，失败时 assert，成功时打印
slub_check() succeeded!。

[RELY]
- 可调用 slub_alloc/slub_free 和 nr_free_pages。
- 支持 8 至 2048 字节 size class，每个 slab 由一页承载。

[GUARANTEE]
- 不修改既有分配器和测试断言，不通过硬编码伪造成功。
- 测试对象的数据写入范围不得超过请求长度。

[SPECIFICATION]
覆盖 0/超大请求、1/8/9/63/64/65/1024/2000 边界、多 cache、
逐字节读写、跨多个 slab、交错释放与复用；最终比较测试前后的
nr_free_pages，确认无物理页泄漏。
```

## 8. 完整回归与报告核对

```text
[PROMPT]
对 Lab2 最终代码执行 clean build、QEMU 运行和课程 inject.py 回归，整理
真实日志、截图、提示词和报告。

[RELY]
- 正常输出包括 Best-Fit 管理器名称及三个 succeeded 信息。
- 课程注入测试检查 Page Init 和 Best-Fit。

[GUARANTEE]
- 不改评分断言；未实际运行的结果不得写成通过。
- code、report、prompt.md、images、evidence 路径必须满足提交规范。

[SPECIFICATION]
检查 check_alloc_page、buddy_system_check、slub_check、Page Init PASS、
Best-Fit PASS，并将命令、覆盖范围、限制和真实日志写入 report.md。
```
