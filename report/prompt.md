# Lab2 提示词汇总

## 1. 功能模块一：实现 `page_init()`

```text
请修改kern/mm/pmm.c中的page_init()，根据设备树提供的memory_base和
memory_size建立物理页描述符布局。设置va_pa_offset、npage和pages；把
[nbase,npage)对应的描述符先全部标记为reserved；将链接符号end之后的
Page描述符数组排除，再将剩余完整页面通过init_memmap注册给当前
pmm_manager。严格区分虚拟地址、物理地址、页号和Page指针，所有边界按
PGSIZE对齐。DTB信息无效时panic，没有完整空闲页时不要调用init_memmap。
只补全标有Lab2和学号的位置，不修改init_memmap、pa2page等框架函数。
```

## 2. 功能模块二：实现并接入 Best-Fit

```text
请阅读default_pmm.c、pmm.h、memlayout.h和best_fit_pmm.c，在不修改
basic_check()与best_fit_check()的前提下，从零补全Best-Fit物理页分配器。
实现初始化、初始空闲区注册、按地址插入、选择满足请求的最小空闲块、拆分、
释放、前后相邻块合并、空闲页计数和best_fit_pmm_manager注册结构。空闲链表
必须按地址有序；相同大小候选保留低地址块；完全匹配可提前结束扫描。最后在
pmm.c的init_pmm_manager中切换到best_fit_pmm_manager，并确保原有测试通过。
```

## 3. 分支任务：观察QEMU中的Sv39地址翻译

```text
请根据当前Lab2源码设计双GDB调试步骤：一个宿主GDB附加QEMU进程，在
riscv_cpu_tlb_fill和get_physical_address附近观察S模式虚拟地址的Sv39遍历；
另一个RISC-V GDB通过QEMU gdbstub连接guest，在kern_init与page_init设置
断点。解释address、access_type、mmu_idx、satp、根页表地址和特权级，说明
两个GDB不能同时冻结同一QEMU进程的原因，并记录丢包、条件断点不命中等问题
及解决办法。所有结论必须来自实际寄存器值、断点和源码，不得仅复述概念。
```

## 4. Challenge第一份提示词：生成并接入SLUB模块

```text
请在当前ucore Lab2中从零实现简化SLUB对象分配器。底层只能通过
alloc_page/free_page获取和归还4KiB页；上层建立8、16、32、64、128、
256、512、1024、2048字节size class。每个slab占一页，页首保存magic、
cache指针、inuse、total、freelist和slab链表指针，剩余空间切成对象并使用
对象内嵌空闲链表。实现slub_init、slub_alloc和slub_free；释放最后一个对象
时必须把整页归还pmm。处理0字节、超大请求、NULL释放、非法指针和重复释放。
新增kern/mm/slub.c和slub.h，并在pmm_init完成页级检查后接入。不得修改
Best-Fit测试函数和既有分配策略，代码必须适应项目的精简头文件和裸机环境。
```

## 5. Challenge第二份提示词：设计SLUB测试

```text
请为上述SLUB实现设计内核态slub_check测试。测试必须覆盖：0字节和超过上限
请求；大小类别边界1/8/9、63/64/65、1024/2000；多个cache同时分配；
写入并读回每个对象的全部请求长度以检查重叠；连续分配足够多的64字节对象以
跨越多个slab；交错释放后再次分配以验证对象复用；释放所有对象后比较
nr_free_pages与测试前完全相等，以证明整页回收且无泄漏。成功时打印
slub_check() succeeded!。测试失败必须触发assert，不得修改既有测试断言。
```

## 6. 启动兼容性诊断与修复

```text
当前Lab2在QEMU 10.2.1中显示OpenSBI Next Address=0x80200000，但写入satp
后停止输出。请使用GDB从物理入口0x80200000单步，检查csrw satp之后的取指
地址和boot_page_table_sv39内容。保持高半区映射，同时增加启动切换所需的低
地址临时恒等映射，使CPU能够执行完sfence.vma并跳转到高地址kern_init。
解释VPN2索引、1GiB叶子PTE和为何旧环境可能没有暴露该问题，并用当前QEMU
重新验证page_init、Best-Fit和SLUB输出。
```

## 7. 完整回归与报告核对

```text
请对Lab2最终仓库执行完整回归：先clean build，再运行QEMU检查管理器名称、
check_alloc_page和slub_check；随后在临时副本中使用课程inject.py注入原有
page_init与Best-Fit测试，在不修改测试断言的前提下运行。整理真实日志、测试
覆盖、实现限制和QEMU版本兼容差异到report.md，补齐Challenge章节、测试截图
和总结，并检查code/report/prompt.md/images目录满足课程提交格式。
```
