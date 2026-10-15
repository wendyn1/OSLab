# 操作系统实验报告

## 实验基本信息

| 项目       | 内容                                 |
| -------- | ---------------------------------- |
| **实验名称** | Lab 2: 物理内存和页表                     |
| **小组成员** | 2411061-牛雨萱、2410721-何熹淳、2414166-滕鑫 |
| **完成日期** | 2026-10-14                         |

### 小组分工

**练习/模块分工：**

| 成员          | 负责的练习/模块             |
| ----------- | -------------------- |
| 2411061-牛雨萱 | 功能模块一：物理内存初始化功能+分支任务 |
| 2410721-何熹淳 | 功能模块二：物理内存分配功能       |
| 2414166-滕鑫  | Challenge SLUB 分配算法  |

**实验报告分工：**

| 成员          | 负责的报告部分                       |
| ----------- | ----------------------------- |
| 2411061-牛雨萱 | 报告骨架 + 功能模块一章节 + 基础验证         |
| 2410721-何熹淳 | 功能模块二章节 + 报告核心章节              |
| 2414166-滕鑫  | Challenge 章节 + 报告整合 + 总结 + 提交 |

***

## 一、实验目的

<!-- 说明本次实验的主要目标和预期成果 -->

本实验的主要目的是：

1. 理解页表的建立和使用方法：掌握 Sv39 三级页表、页表项（PTE）结构、`satp` 寄存器与 TLB（快表）的作用，理解内核如何通过大页映射实现虚拟地址到物理地址的转换
2. 理解物理内存的管理方法：掌握物理内存的探测（设备树 DTB）、以页为单位的 `Page` 描述符组织方式、空闲页链表的建立，以及虚拟地址/物理地址的转换（`PADDR`/`KADDR`、`va_pa_offset`）
3. 理解页面分配算法：理解 First-Fit 连续分配的实现过程，动手实现 Best-Fit 分配器，并通过 SLUB 扩展任务了解页级分配之上的任意大小内存对象分配
4. 学习使用 AI 辅助开发操作系统核心功能：通过设计提示词（prompt）借助 AI 生成并迭代 `page_init()`、Best-Fit、SLUB 等模块，体验"规格化需求 → AI 生成 → 测试迭代"的开发范式

***

## 二、实验环境

你们使用的 AI 工具

| 成员          | AI 编程工具    | 底层模型  | 备注     |
| ----------- | ---------- | ----- | ------ |
| 2411061-牛雨萱 | Codex 桌面应用 | GPT-6 | <br /> |
| 2410721-何熹淳 | Codex 桌面应用 | GPT-6 | <br /> |
| 2414166-滕鑫  | Codex 桌面应用 | GPT-6 | <br /> |

**说明：**

- **AI 编程工具**：指具体使用的终端工具、编辑器插件、桌面应用或浏览器界面
- **底层模型**：指该工具使用的大语言模型及版本

***

## 三、实验整体逻辑分析

### 2.1 本章节的逻辑主线

本实验围绕 **物理内存的发现、初始化与分配** 展开，同时结合分页机制理解"虚拟地址 → 物理地址"的映射。

实验一已经做出了一个能在裸机上启动的系统，但从那之后内核的内存资源是"无人管理"的：内核不知道机器里有多少物理内存，也无法在需要时为内核或后续进程分配内存。因此 lab2 的核心问题是：**操作系统如何高效地组织和管理物理内存资源？**

整个实验的实现链可以概括为：

```
pmm_init() -> init_pmm_manager() -> page_init() -> init_memmap() -> alloc_pages()/free_pages()
```

即：先选定并初始化一个物理内存管理器（pmm\_manager），再从设备树（DTB）中探测物理内存范围，由 `page_init()` 建立物理页描述符（`Page` 数组）并把可用的完整页面交给内存管理器登记为空闲页；之后内核便可以通过 `alloc_pages()` / `free_pages()` 按页分配与回收物理内存。此外，`entry.S` 在进入 `kern_init()` 之前已经建立了 Sv39 启动页表（`boot_page_table_sv39`）并设置 `satp` 开启了分页，因此本实验的物理内存初始化是在分页模式下建立 `Page` 描述符和初始空闲页区间，这也帮助我们直观地理解"页表把虚拟地址空间与物理内存衔接起来"这一抽象。

### 2.2 功能的逐步实现

本实验按照"先有内存认知、后有内存分配、最后抽象升级"的顺序逐步实现各个功能：

1. 首先实现**功能模块一：物理内存探测与页描述符初始化（`page_init`）** → 为什么首先实现这个？因为任何内存分配都建立在"知道有多少物理内存、内存长什么样"的前提之上。内核通过设备树获得物理内存的基址与大小，计算 `va_pa_offset`、`npage`，把 `Page` 描述符数组放置在内核镜像之后，将 OpenSBI、内核镜像与描述符数组所占区域排除后，把剩余完整页面交给 `pmm_manager` 登记。这一步是所有后续分配功能的基石。
2. 接着理解**功能模块二·任务一：First-Fit 连续分配算法** → 为什么先理解这个？因为 First-Fit 是最基础的连续物理内存分配方法，通过阅读 `default_pmm.c` 中 `default_init`、`default_init_memmap`、`default_alloc_pages`、`default_free_pages` 等函数，可以掌握"空闲页链表 + property 合并"这一完整分配/回收流程，为后续实现其他算法提供模板。
3. 然后实现**功能模块二·任务二：Best-Fit 连续分配算法** → 为什么接着实现这个？在理解了 First-Fit 之后，设计提示词让 AI 在 `best_fit_pmm.c` 中实现完整的 Best-Fit 分配器，并在 `init_pmm_manager()` 中把物理内存管理器切换为 `best_fit_pmm_manager`。Best-Fit 在分配时选择"满足需求且最接近"的空闲块，能有效减少外部碎片，是对 First-Fit 的直接改进，进一步加深对连续分配策略差异的理解。
4. 最后补充**Challenge·任务四：SLUB 分配算法** → 为什么最后实现这个？SLUB 采用两层架构：第一层是基于页大小的分配（复用 `alloc_pages`/`free_pages`），第二层在页之上实现任意大小内存对象的分配。它建立在页级分配器之上，属于更上层的内存抽象；作为选做加分项，它让我们看到"页级分配 → 对象分配"的完整内存管理层次。

***

## 四、实验内容与实现

<!-- 
说明：本部分按照 exercises 文档中的练习顺序组织
每个功能模块或者练习中可能包含多项任务，请根据实际情况调整
-->

### 功能模块：**【功能模块一：物理内存初始化功能】**

**负责人：** 2411061-牛雨萱

#### 模块功能描述

**需要实现/修改的函数：**

```c
// 列出本模块涉及的所有函数签名
static void page_init(void); 
```

**功能说明：**

- 该模块在整个系统中的作用
  page\_init() 是物理内存管理的入口。它把设备树探测到的物理内存范围转换为内核可管理的物理页描述符数组，并把排除 OpenSBI、内核镜像、Page 描述符数组及对齐空隙之后的完整空闲页，交给当前 pmm\_manager（本实验为 default\_pmm\_manager）管理。没有它，后续 alloc\_pages() / free\_pages() 无页可分，虚拟内存、进程、文件系统等模块全部无法建立。
- 需要处理的主要场景

1. 正常初始化：DTB 信息有效，物理内存范围 \[0x80000000, 0x88000000)，存在完整空闲页。
2. DTB 信息无效：memory\_base == 0 或 memory\_size == 0，调用 panic() 终止初始化。
3. 无可用完整页面：描述符数组之后到物理内存末尾不足一页，不调用 init\_memmap()，直接返回。

- 与其他模块的交互关系]
  上游：kern/driver/dtb.c 提供 get\_memory\_base() / get\_memory\_size()；tools/kernel.ld 提供链接符号 end。
  同层：kern/mm/memlayout.h 提供 struct Page、PG\_reserved / PG\_property 及页面状态宏；kern/mm/pmm.h 提供 PADDR、npage、nbase、pages、va\_pa\_offset。
  下游：通过 init\_memmap() 把空闲区注册给 pmm\_manager；pmm\_init() 随后调用 check\_alloc\_page() 验证。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown
[PROMPT]
**任务**：修改文件 kern/mm/pmm.c，实现物理内存探测与 Page 描述符初始化功能，
具体实现 page_init() 函数。该函数需要根据设备树提供的物理内存信息建立可管理
物理页的描述符布局，并把排除 OpenSBI、内核镜像和描述符数组占用空间后的完整
空闲页面交给当前 pmm_manager 管理。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。保留文件中的现有
代码，只在 page_init() 函数体内标有 lab2 和 YOUR CODE 的位置补全实现，不要删除
既有逻辑。

**输出要求**：直接进行文件操作。使用下面 [RELY]、[GUARANTEE]、[SPECIFICATION]
部分提供的信息，以工程真实代码为准，不要引入无关功能。

[RELY]

### 宏定义

// 来自 kern/mm/mmu.h
#define PGSIZE          4096
#define PGSHIFT         12

// 来自 libs/riscv.h
#define DRAM_BASE       0x80000000

// 来自 kern/mm/memlayout.h
#define KERNBASE        0xFFFFFFFFC0200000

// 来自 libs/defs.h
#define ROUNDDOWN(a, n)
#define ROUNDUP(a, n)

// 来自 kern/mm/pmm.h
#define PADDR(kva)  ({ uintptr_t __m_kva = (uintptr_t)(kva); \
                       if (__m_kva < KERNBASE) panic(...); \
                       __m_kva - va_pa_offset; })

### 数据结构

// 来自 kern/mm/memlayout.h
struct Page {
    int ref;                    // page frame's reference counter
    uint64_t flags;             // array of flags that describe the status of the page frame
    unsigned int property;      // the num of free block, used in first fit pm manager
    list_entry_t page_link;     // free list link
};

### 页面状态宏

// 来自 kern/mm/memlayout.h
#define SetPageReserved(page)       ((page)->flags |= (1UL << PG_reserved))
#define ClearPageReserved(page)     ((page)->flags &= ~(1UL << PG_reserved))
#define PageReserved(page)          (((page)->flags >> PG_reserved) & 1)
#define SetPageProperty(page)       ((page)->flags |= (1UL << PG_property))
#define ClearPageProperty(page)     ((page)->flags &= ~(1UL << PG_property))
#define PageProperty(page)          (((page)->flags >> PG_property) & 1)

### 地址转换函数

// 来自 kern/mm/pmm.h
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
}

### 全局变量

// 来自 kern/mm/pmm.c
struct Page *pages;
size_t npage = 0;
uint64_t va_pa_offset;
const size_t nbase = DRAM_BASE / PGSIZE;

### 可用函数

// 来自 kern/driver/dtb.c
uint64_t get_memory_base(void);
uint64_t get_memory_size(void);

// 来自 libs/stdio.h
int cprintf(const char *fmt, ...);

// 来自 kern/debug（宏，自动带 __FILE__ / __LINE__）
panic(fmt, ...)

// 来自 kern/mm/pmm.c
static void init_memmap(struct Page *base, size_t n);

### 链接符号

// 来自 tools/kernel.ld
extern char end[];

[GUARANTEE]
必须实现或修改的接口：
```c
static void page_init(void);


你可以根据需要添加：
- 辅助函数（建议设为 static）
- 内部使用的宏定义
- 模块内部的静态变量

[SPECIFICATION]

## page_init

**Pre-Condition**:
- pmm_init() 已调用 init_pmm_manager()，pmm_manager 已指向有效的管理器
- dtb_init() 已执行，get_memory_base() 和 get_memory_size() 返回 DTB 探测到的
  物理内存起始和大小
- 链接符号 end 指向内核代码结尾（虚拟地址）
- 分页机制已开启，va_pa_offset 尚未设置

**Post-Condition**:
- va_pa_offset、npage、pages 已正确设置
- [nbase, npage) 中所有描述符初始为 reserved 状态
- 描述符数组之后、物理内存末尾之前的完整空闲页已通过 init_memmap() 注册
- 已用 cprintf() 输出探测到的物理内存范围

**Case 1（正常初始化）**:
- 触发条件：memory_base != 0 && memory_size != 0 && npage > nbase
- 执行行为：计算 va_pa_offset、npage；在 end 之后按页对齐放置 Page 描述符
  数组，赋给 pages；给 [nbase, npage) 所有描述符 SetPageReserved；计算描述符
  数组之后按页对齐的物理地址作为空闲区起点 freemem；计算物理内存末尾按页向下
  对齐作为空闲区终点；若 freemem < mem_end，调用 init_memmap(pa2page(freemem),
  (mem_end - freemem) / PGSIZE)
- 最终状态：全局变量正确设置，空闲页注册完成，cprintf 输出物理内存范围

**Case 2（DTB 信息无效）**:
- 触发条件：memory_base == 0 || memory_size == 0
- 执行行为：调用 panic() 终止初始化
- 最终状态：内核 panic，不继续执行

**Case 3（无可用完整页面）**:
- 触发条件：freemem >= mem_end
- 执行行为：不调用 init_memmap()，直接返回
- 最终状态：va_pa_offset、npage、pages 仍正确设置，但空闲页数为 0

**Requirements**:
- 必须严格区分虚拟地址、物理地址、物理页号和 Page 描述符地址，不能混用
- end 是虚拟地址，要用 PADDR() 转成物理地址后再参与空闲区计算
- 描述符数组起点、空闲区起点、空闲区终点都必须按 PGSIZE 对齐
- 必须确保 [0x80000000, KernelEnd) 和描述符数组本身不进入空闲区
- 必须先给所有描述符 SetPageReserved，再对空闲区调用 init_memmap()
- 禁止修改 init_memmap()、default_init_memmap()、pa2page() 等已有函数

````

#### 实现迭代过程

本模块的实现经历了 \[1] 次迭代，过程如下：

***

##### 第一次迭代

如果设计的prompt生成代码后出现问题：

**遇到的问题：**

- 问题 1：编译阶段，kern/mm/best\_fit\_pmm.c 报错

```
error: 'free_list' undeclared (first use in this function)
error: 'nr_free' undeclared (first use in this function)
```

错误信息指向 basic\_check() 和 best\_fit\_check() 两个测试函数中使用的 free\_list 和 nr\_free 标识符。

原因分析：best\_fit\_pmm.c 是功能模块二待实现的文件，其框架中已经提供了 basic\_check() 和 best\_fit\_check() 两个测试函数，测试函数直接使用了 free\_list 和 nr\_free 两个标识符。但这两个标识符应该由 best\_fit\_pmm.c 内部定义。

**问题解决策略：**

- 针对问题 1：在 best\_fit\_pmm.c 顶部补充以下三行定义：

```
free_area_t free_area;
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)
```

该补充属于功能模块二的范畴，但为了能让整个 lab2 编译通过、先行验证 page\_init()，需要提前补上。补充后重新 make，编译通过。

**最终结果：**

经过 \[1] 次迭代，该模块最终：

- ✅ 编译通过（make 无 error / warning）
- ✅ 所有相关测试通过（make qemu 输出 check\_alloc\_page() succeeded!）
- ✅ 功能符合预期（npage = 0x88000、nbase = 0x80000、va\_pa\_offset = 0xffffffff40000000、pages = 0xffffffffc0207000、nr\_free\_pages() = 31929）

**关键改进点总结（如有）：**

1. 在编译阶段补齐了 best\_fit\_pmm.c 的 free\_area\_t free\_area; 及 free\_list / nr\_free 宏定义，使整个 lab2 可以顺利编译，从而能够先行验证 page\_init()。
2. 在 GDB 验证阶段，明确了"断点位置决定观测值"这一要点：必须在 page\_init() 执行完之后（如 check\_alloc\_page 断点处）查看 nr\_free\_pages()，才能得到正确的空闲页数。

***

### 功能模块：**【】**

**负责人：** 

#### 模块功能描述

**需要实现/修改的函数：**

```c
// 列出本模块涉及的所有函数签名

```

**功能说明：**

\[简要描述该模块的功能，包括：

- 该模块在整个系统中的作用
- 需要处理的主要场景
- 与其他模块的交互关系]

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

```markdown
[按照提示词模板，给出具体的提示词]

```

#### 实现迭代过程

本模块的实现经历了 \[N] 次迭代，过程如下：

***

##### 第一次迭代

如果设计的prompt生成代码后出现问题：

**遇到的问题：**

- 问题1：问题描述、错误信息和原因分析
- 问题2：问题描述、错误信息和原因分析

**问题解决策略：**

- 针对问题1：\[说明如何修改提示词]
- 针对问题2：\[说明如何修改提示词]

如果没有问题：

**最终结果：**

经过 \[N] 次迭代，该模块最终：

- ✅ 编译通过
- ✅ 所有相关测试通过
- ✅ 功能符合预期

**关键改进点总结（如有）：**

1. \[改进点1：例如，在 \[RELY] 中补充了完整的系统调用号定义]
2. \[改进点2：例如，在 \[SPECIFICATION] 中明确了异常处理的边界条件]
3. \[改进点3：例如，增加了对用户指针合法性检查的要求]

***

##### 第二次迭代（如有）

\[按照和第一次迭代相同的格式]

***

##### 第三次迭代（如有）

\[按照和第一次迭代相同的格式]

***

### 练习：\[练习标题]

**负责人：** \[学号-姓名]

\[按照练习的具体要求进行解答]

***

### Challenge：\[Challenge标题]

**负责人：** \[学号-姓名]

\[按照Challenge的具体要求进行解答]

***

### 分支任务：gdb 调试页表查询过程

**负责人：** 2411061-牛雨萱

本分支任务采用"QEMU 源码分析 + 三层终端双 GDB 实测"的方式，完整观察一次"虚拟地址 → SV39 三级页表遍历 → 物理地址"的翻译全过程，按以下 6 个问题进行解答。

#### 问题 1：QEMU 源码中地址翻译的关键调用路径

关键路径（QEMU 4.1.1）：

```
riscv_cpu_tlb_fill()          [target/riscv/cpu_helper.c]
  → get_physical_address()    [target/riscv/cpu_helper.c]
      → 遍历三级页表（SV39）
      → 检查 PMP
      → 返回物理地址
  → tlb_set_page()            [accel/tcg/cputlb.c]
```

关键分支语句（`riscv_cpu_tlb_fill` 末尾，cpu\_helper.c）：

```c
if (ret == TRANSLATE_SUCCESS) {
    tlb_set_page(cs, address & TARGET_PAGE_MASK, pa & TARGET_PAGE_MASK,
                 prot, mmu_idx, TARGET_PAGE_SIZE);
    return true;
}
```

含义：guest 每次访存/取指时，TCG 先查询 QEMU 的软件 TLB；未命中时进入 `riscv_cpu_tlb_fill()`，由 `get_physical_address()` 完成页表遍历得到物理地址 `pa`，若翻译成功（`TRANSLATE_SUCCESS`）则调用 `tlb_set_page()` 把整页映射写入软件 TLB，供后续访存快速命中。

#### 问题 2：页表翻译的关键操作流程

`get_physical_address()` 针对 SV39（`levels = 3`、`ptidxbits = 9`、`ptesize = 8`）的核心流程：

```c
base = get_field(env->satp, SATP_PPN) << PGSHIFT;   // 根页表物理地址
...
for (i = 0; i < levels; i++, ptshift -= ptidxbits) {
    target_ulong idx     = (addr >> (PGSHIFT + ptshift)) & ((1 << ptidxbits) - 1);
    target_ulong pte_addr = base + idx * ptesize;     // 本级页表项地址
    target_ulong pte     = ldq_phys(cs->as, pte_addr); // 读 PTE（RV64 为 8 字节）
    target_ulong ppn     = pte >> PTE_PPN_SHIFT;

    if (!(pte & PTE_V)) return TRANSLATE_FAIL;        // 有效位检查
    if (!(pte & (PTE_R | PTE_W | PTE_X))) {
        base = ppn << PGSHIFT;                        // 中间级 PTE：指向下一级页表
    } else {
        /* 叶子 PTE：*physical = (ppn << PGSHIFT) | (addr & (PGSIZE - 1)) */
    }
}
```

三级层次逐级对应：

- **第一级（根页表）**：从 `satp` 指向的页表，按 VPN\[2] 取 PTE，若有效位 V 为 0 则返回 `TRANSLATE_FAIL`
- **第二级**：从上一级 PTE 的 PPN 提取下一级页表基址（`base = ppn << PGSHIFT`），按 VPN\[1] 取 PTE
- **第三级（叶子）**：再按 VPN\[0] 取 PTE，最终物理地址 = 叶子 PTE 的 `PPN << 12 | 页内偏移`

#### 问题 3：QEMU 模拟 TLB 的 C 代码

QEMU 中的 TLB 实现在 `accel/tcg/cputlb.c`，关键函数是 `tlb_set_page()`。它把翻译结果写入 CPU 的软件 TLB 数组（`cpu->tlb_table`），TCG 翻译后的访存指令会先查这张表。

**注意**：QEMU 的 TLB 与真实 CPU TLB 有本质区别：

- QEMU 的 TLB 是软件缓存，用于加速"虚拟地址 → 主机地址（RAM）"的映射，目的是加快 TCG 翻译执行
- 它不模拟真实 CPU TLB 的命中/未命中行为，也不会因未命中产生模拟性能代价

#### 问题 4：QEMU TLB vs 真实 CPU TLB

| 特性       | 真实 CPU TLB       | QEMU TLB                   |
| -------- | ---------------- | -------------------------- |
| 本质       | 硬件缓存（SRAM 阵列）    | 软件数据结构（数组）                 |
| 作用       | 加速 虚拟地址→物理地址 转换  | 加速 虚拟地址→主机地址 转换            |
| 命中/未命中   | 有性能影响（未命中需重新走页表） | 无模拟（纯软件查表，未命中即调 tlb\_fill） |
| info tlb | 显示真实 TLB 状态      | 显示页表映射结果，不是硬件 TLB 状态       |

#### 问题 5：调试细节记录（三层终端双 GDB 实测）

**调试架构：**

| 终端  | 用途                                                                               | 控制层面                              |
| --- | -------------------------------------------------------------------------------- | --------------------------------- |
| 终端一 | `make debug`：QEMU 以 `-s -S` 启动（`-s` 开放 1234 端口 gdbstub；`-S` 冻结 guest CPU 等待 GDB） | 串口输出，观察 guest 引导与内核启动             |
| 终端二 | 原生 x86 gdb attach QEMU 宿主进程（PID 711）                                             | ptrace 控制整个 QEMU 进程，观察地址翻译函数      |
| 终端三 | `riscv64-unknown-elf-gdb` 连接 `localhost:1234`                                    | gdbstub 控制 guest vCPU，调试 ucore 内核 |

**Step 1 环境准备（终端二）：**

- 修复 Makefile：WSL 下 QEMU 路径必须使用正斜杠 `/mnt/e/OS/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64`；反斜杠会被 Makefile 解析为转义符，导致 `make: E:OSqemu-4.1.1riscv64-softmmuqemu-system-riscv64: No such file or directory`
- 安装缺失的原生 gdb：`sudo apt install -y gdb`
- `pgrep -f qemu-system-riscv64` 获取 QEMU 进程 PID=711

**Step 2 终端一启动 QEMU（串口关键输出）：**

```
OpenSBI v0.4 ...
DTB Address: 0x82200000
Physical Memory from DTB:
  Base: 0x0000000080000000
  Size: 0x0000000008000000 (128 MB)
  End:  0x0000000087ffffff
(THU.CST) os is loading ...
Special kernel symbols:
  entry  0xffffffffc02000d8 (virtual)
  end    0xffffffffc0206078 (virtual)
memory management: default_pmm_manager
```

DTB 探测到物理内存 \[0x80000000, 0x88000000)，内核符号均为高端虚拟地址（KERNBASE 映射区）。此时 vCPU 因 `-S` 冻结在复位向量 0x1000。
![终端一](images\终端1.png)
**Step 3 终端二 attach 宿主进程并下断点：**

```
(gdb) attach 711
(gdb) handle SIGPIPE nostop noprint                          # 忽略 QEMU 管道断开信号
(gdb) break get_physical_address if addr == 0xffffffffc0200000   # 条件断点①
(gdb) continue → ^C                                          # 长时间未命中，中断
(gdb) break get_physical_address                             # 无条件断点②，命中一次：
      get_physical_address(..., addr=0, access_type=0, mmu_idx=3)
```

- 断点①未命中的原因：guest 被 `-S` 冻结，内核尚未运行，目标地址从未被翻译
- 断点②虽命中，但 `mmu_idx=3` 即 PRV\_M，M 模式翻译直接 `*physical = addr` 返回、不走页表遍历，无观察价值 → 删除
- 改为在 TLB 填充入口下断点：

```
(gdb) break riscv_cpu_tlb_fill                                            # 断点③（无条件）
(gdb) break riscv_cpu_tlb_fill if address == 0xffffffffc02010f2           # 断点④（条件，page_init 地址）
```

**Step 4 终端三连接 guest 并放开 CPU：**

- 初次连接报 `Ignoring packet error` / `Remote replied unexpectedly to 'vMustReplyEmpty': timeout`：根因是终端二曾把 QEMU 冻结（断点/Ctrl+C），gdbstub 无法响应 → 让终端二处于 `Continuing.` 状态后重连成功
- 连接成功后读到 `0x0000000000001000 in ??`（guest 仍冻结在复位向量，属正常）
- 设置并命中内核断点：

```
(gdb) break kern_init
(gdb) continue
Breakpoint 1, kern_init () at kern/init/init.c:30       # memset(edata, 0, end - edata);
(gdb) break page_init
(gdb) continue
Breakpoint 2, page_init () at kern/mm/pmm.c:67          # uint64_t memory_base = get_memory_base();
(gdb) info registers pc
pc  0xffffffffc02010f2  <pmm_init+52>
```

guest 内核成功进入 `kern_init → pmm_init → page_init`，全程运行在 S 模式。
![终端三](images\终端3_1.png)
![终端三](images\终端3_2.png)
**Step 5 终端二观察地址翻译（与 Step 4 并行）：**

命中 `riscv_cpu_tlb_fill`：

```
riscv_cpu_tlb_fill(cs=0x5ef0adb710e0, address=18446744072637935624, size=8,
                   access_type=MMU_DATA_LOAD, mmu_idx=1, probe=false, ...)
```

- `address = 0xffffffffc0207008`（十进制还原，= KERNBASE + 0x7008，处于 `pages` 描述符数组区，对应内核运行期访问 Page 描述符）
- `size = 8`：一次 8 字节访存（ld 指令）
- `access_type = MMU_DATA_LOAD`：数据读
- `mmu_idx = 1`：PRV\_S，S 模式内核访存 → 真正走 SV39 三级页表遍历

继续观察寄存器状态：

```
(gdb) p env->satp
$4 = 9223372036855300613 = 0x8000000000080205
   → satp.mode = 8（SV39）；satp.ppn = 0x80205 → 根页表物理地址 0x80205000
(gdb) p env->priv
$5 = 1    # PRV_S，确认内核运行在 S 模式
```

`continue` 后再次命中（`address = 0xffffffffc0208200`，同样位于描述符区），说明内核运行期频繁访问该区，翻译过程可重复观察。


![终端二](images\终端2_1.png)
![终端二](images\终端2_2.png)
![终端二](images\终端2_3.png)

**Step 6 遇到的问题与解决：**

1. 无条件断点随每次 TLB fill 命中 → QEMU 宿主进程反复冻结 → 终端三丢包。解决：改用条件断点（限定目标虚拟地址 / `mmu_idx==1`）或观察完即删除
2. 条件断点①未命中：guest 冻结未运行内核 → 先通过终端三 `continue` 放开 CPU 再等待命中
3. 终端二与终端三是"同一 QEMU 进程、两个控制层面"：终端二（ptrace）冻结进程时，终端三（gdbstub）必然失联，二者须错峰操作

**结论：** 双 GDB 架构成功打通。终端二证明：S 模式内核访存（`mmu_idx=1`）进入 `riscv_cpu_tlb_fill → get_physical_address` 的 SV39 三级遍历路径，根页表物理地址 0x80205000；终端三证明：guest 内核在 S 模式下执行 `kern_init → page_init`。两端对照即可完整还原"虚拟地址 0xffffffffc020xxxx → 三级页表遍历 → 物理地址"的翻译全过程。

#### 问题 6：大模型交互记录

调试过程中与 AI 的交互记录：

| 遇到的问题                                                  | AI 的解决方案                                                                                               |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `make debug` 报 `E:OSqemu... No such file or directory` | WSL 下 Makefile 中反斜杠会被当作转义符，改为正斜杠绝对路径 `/mnt/e/OS/qemu-4.1.1/riscv64-softmmu/qemu-system-riscv64`        |
| 遗忘 WSL 用户 sudo 密码                                      | 在 Windows 侧以 `wsl -u root` 进入 root 身份，执行 `passwd` 重置普通用户密码                                             |
| `sudo gdb` 报 `gdb: command not found`                  | 执行 `sudo apt update && sudo apt install -y gdb` 安装原生 x86 gdb                                           |
| `make debug` 启动后长时间无输出                                 | 解释 `-s -S` 参数含义：guest CPU 冻结等待 GDB，无输出属正常现象                                                            |
| 终端三连不上、报 `Ignoring packet error` / timeout             | 解释三层终端"同一进程、两个层面"的关系：终端二（ptrace）冻结 QEMU 时 gdbstub 无法响应，需终端二处于 `Continuing.` 状态                         |
| 条件断点 `addr == 0xffffffffc0200000` 不命中                  | guest 冻结未运行内核，目标地址从未被翻译；先通过终端三 `continue` 放开 CPU                                                       |
| 无条件断点命中 `addr=0, mmu_idx=3`                            | 分析 `mmu_idx=3` 即 PRV\_M，M 模式翻译直接返回物理地址、不走页表，无观察价值；建议改在 `riscv_cpu_tlb_fill` 下断点并用 `mmu_idx==1` 过滤 S 模式 |
| 不理解 satp / 十进制地址的含义                                    | 帮助解码：`satp=0x8000000000080205` → SV39 + 根页表 0x80205000；十进制地址还原为 `0xffffffffc0207008`                   |

**AI 协作经验小结：**

1. 宿主侧断点必须加条件：无条件断点会冻结整个 QEMU，导致 guest 侧 gdb 丢包
2. 先放行 CPU 再下目标断点：guest 未运行前，针对内核虚拟地址的条件断点不会命中
3. 观测值要与内核符号表（entry / end / pages 地址）对照，才能确定被翻译地址的真实含义

***

## 五、测试与验证

<!-- 根据该实验的具体情况，提供完整的测试运行截图，应包含：

- 编译及运行成功的输出（make qemu），可能有多个
- 测试通过的结果（make grade），只有一个
  -->

### 5.1 测试 page\_init() 函数

**验证方法：**

1. `make` 编译通过，无 error / warning。
2. `make qemu` 观察串口输出。
3. GDB 断点 `check_alloc_page`，查看 `page_init()` 执行后的全局变量。

**验证结果：**

| 验证项                  | 输出                   | 含义                                     | 正确性 |
| -------------------- | -------------------- | -------------------------------------- | --- |
| `npage`              | `557056`（`0x88000`）  | 可管理物理页号上界 = 128MB / 4KB                | ✅   |
| `nbase`              | `524288`（`0x80000`）  | DRAM 起始物理页号 = `0x80000000` / 4KB       | ✅   |
| `va_pa_offset`       | `0xffffffff40000000` | 虚实偏移 = KERNBASE - DRAM\_BASE           | ✅   |
| `pages`              | `0xffffffffc0207000` | `Page` 描述符数组起始虚拟地址 = `end` 之后按页对齐      | ✅   |
| `nr_free_pages()`    | `31929`              | 空闲物理页数 ≈ 128MB/4KB − 内核 − 描述符数组 − 对齐空隙 | ✅   |
| `check_alloc_page()` | `succeeded!`         | `default_check()` 全部通过                 | ✅   |

**验证结论：**

`page_init()` 正确设置了 `va_pa_offset`、`npage`、`pages`，正确保留了 OpenSBI、内核镜像、`Page` 描述符数组所占页面，空闲页数合理，`check_alloc_page() succeeded!` 表明 `default_pmm_manager` 的分配 / 释放逻辑在初始空闲区上全部通过。功能模块一 · 任务一完成。

**测试截图：**
![测试结果截图](./images/page_init\(\)_make.png)
![测试结果截图](./images/page_init\(\)_makeqemu.png)
![测试结果截图](./images/page_init\(\)_gdb.png)

***

## 六、实验总结与收获

### 对操作系统的理解

1. 本实验中的重要知识点及其与 OS 原理中知识点的对应关系：

| 本实验中的知识点                                          | OS 原理中的知识点                                 | 含义、关系与差异                                                                                                                                                                                                                                               |
| ------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `struct Page` 页描述符数组                              | 物理页框（frame）管理                              | OS 原理把物理内存划分为固定大小的页框，由页描述符记录每个页框的状态；ucore 用一个连续的 `Page` 数组（由 `nbase`、`npage` 界定范围）为所有可管理物理页建立描述符，通过 `SetPageReserved` 等标志位标记状态，是原理中"页框管理"的代码落地                                                                                                         |
| `pmm_manager` 框架与空闲页链表                            | 连续内存分配算法（First-Fit / Best-Fit / Worst-Fit） | 原理中的连续分配算法描述策略层面的"如何选择空闲块"；ucore 用 `struct pmm_manager` 统一抽象出 init / init\_memmap / alloc\_pages / free\_pages / nr\_free\_pages / check 等接口，再分别用 `default_pmm_manager`（First-Fit）和 `best_fit_pmm_manager`（Best-Fit）实现，通过空闲页链表上的 `property` 记录块大小并实现合并 |
| `PADDR` / `KADDR`、`va_pa_offset`、`nbase`          | 逻辑地址与物理地址的转换、地址空间布局                        | 原理中地址转换由 MMU 完成；ucore 在软件侧维护"虚拟地址 = 物理地址 + 偏移"的关系（`va_pa_offset = KERNBASE - KERNEL_BEGIN_PADDR`），`PADDR`/`KADDR` 即内核镜像区虚实地址的双向换算，`pa2page` 则完成物理地址到描述符下标（物理页号）的换算                                                                                     |
| 设备树（DTB）物理内存探测                                    | 系统启动时的内存配置发现                               | 原理中通常假定 OS 从固件/BIOS 获得内存信息；ucore 通过 `get_memory_base()` / `get_memory_size()` 从设备树读取物理内存基址与大小，使内核无需硬编码内存布局，运行时即可知道可管理的内存范围                                                                                                                             |
| Sv39 三级页表、页表项（PTE）、1 GiB 大页                       | 页式内存管理、多级页表                                | 原理中页表项包含物理页号与标志位（有效位 V、读写执行权限 R/W/X、访问位 A、脏位 D 等）；ucore 的启动页表把 `[0xffffffffc0000000, 0xffffffffffffffff]` 用一个叶子大页映射到 `[0x80000000, 0xc0000000)`，并用 `satp` + `sfence.vma` 开启分页，体现了多级页表"按需建项、节省内存"的思想                                                    |
| TLB 与 `sfence.vma`                                | 快表（Translation Lookaside Buffer）           | 原理中 TLB 利用时间和空间局部性缓存近期虚实映射、减少页表访问次数；ucore 在修改 `satp` 后必须执行 `sfence.vma` 刷新 TLB，保证新旧映射一致，这正是原理中"TLB 一致性"问题的具体体现                                                                                                                                         |
| `pmm_init() -> init_memmap() -> alloc/free_pages` | 内存管理初始化与分配回收闭环                             | 原理中内核先初始化内存管理数据结构再提供服务；ucore 的调用链完整呈现了"探测 → 建描述符 → 注册空闲区 → 分配/回收"的生命周期，分配时在空闲链表上取下满足要求的块，回收时合并相邻空闲块并归还链表                                                                                                                                               |

1. OS 原理中很重要、但在本实验中没有对应上的知识点：

- **缺页异常与页面置换算法（swap）**：本实验只完成了物理内存的管理与页表映射，没有实现虚拟存储，也就没有"缺页 → 换入换出"的处理流程（后续 lab9 会涉及）。
- **虚拟内存 / 逻辑地址空间的管理**：本实验中的虚拟地址空间是内核的一张大页映射，尚未涉及进程各自的地址空间、内存映射区域（vma）以及按需分配等抽象（后续 lab4/lab5 会涉及）。
- **伙伴系统（Buddy System）**：本实验的扩展只选择了 SLUB，而原理中 Buddy 是内核内存管理的重要算法；其按 2 的幂次划分/合并块的思想与 First-Fit/Best-Fit 差异显著。
- **页表项的动态建立与多级页表的完整构造**：本实验的启动页表是在汇编中静态构造的一级大页映射，尚未实现运行时动态创建/撤销页表项、缺页时按需填项的过程。
- **页面的换出与内存回收的整体机制**：原理中还包括页面置换策略、内存回收阈值、内核对象缓存（slab/slub 的完整实现）等，本实验只实现了最基础的物理页分配与对象分配雏形。

### AI 协作开发的经验

本次实验是全程与 AI 协作完成的，几点实际感悟：

1. **把需求"规格化"比"描述性"提示有效得多**：功能模块一（`page_init`）的成功关键在于提示词中明确了前置条件与后置条件——必须区分虚拟地址、物理地址、物理页号和 `Page` 描述符地址，所有地址按 `PGSIZE` 对齐，`end` 符号要先用 `PADDR()` 转成物理地址再计算空闲区，`[nbase, npage)` 全部描述符先置为 reserved，再调用 `init_memmap`。AI 生成代码时严格遵循这些约束，一次就接近正确。
2. **"负面约束"要写进提示词**：例如"不得修改 `init_memmap`、`pa2page` 等现有函数""不得修改测试函数 `basic_check` / `best_fit_check`""设备树信息无效时必须 `panic`、没有完整空闲页时不得调用 `init_memmap`"，这类约束有效防止了 AI 为了通过测试而"偷改框架"。
3. **报错信息原样回传、小步迭代**：当 AI 生成的代码出现编译错误或逻辑错误时，把完整的错误信息（含文件行号）直接反馈给它，让它基于错误做定向修复，比笼统地说"有问题"收敛更快。实现过程中经历了"先写对主路径、再补边界分支（DTB 无效、无空闲页）"的多轮迭代。
4. **AI 生成 ≠ 正确，人工 review 不可省**：生成的代码必须对照实验手册的调用链 `pmm_init() -> init_pmm_manager() -> page_init() -> init_memmap() -> alloc_pages()/free_pages()` 逐段核对语义，特别是地址换算与对齐这类"错了也不报错"的隐蔽问题，只能靠人理解内存布局来发现。
5. **小组分工与交接要围绕"统一的知识基线"**：本次采用 A（骨架+功能模块一）→ B（功能模块二）→ C（Challenge+整合+提交）的接力式分工，由于三人都基于同一份指导书、同一套 `pmm_manager` 框架，交接时只需交代"改动了哪些文件、在哪个函数、遵循什么约束"，衔接成本很低，也保证了报告与代码的一致性。

***

