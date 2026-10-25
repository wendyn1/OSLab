# Lab2 提示词汇总

以下提示词统一采用课程示例中的 `[PROMPT]`、`[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 四段格式。代码生成与测试设计分别记录，不将测试要求混入实现提示词。

## 1. 功能模块一：实现 `page_init()`

```text
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

```

## 2. 功能模块二：实现并接入 Best-Fit

```text
[PROMPT]

请在 C:\Users\xin20\Desktop\OSLab-lab2 项目中，
完成功能模块二任务二：Best-Fit 连续物理内存分配算法。

请直接修改实际代码，不要只展示示例。

主要修改文件：
1. code/lab2/kern/mm/best_fit_pmm.c
2. code/lab2/kern/mm/pmm.c

如确有必要，可以补充 best_fit_pmm.h 中的管理器声明。
不要修改其他功能模块。

[RELY]

请先阅读以下实际文件，以项目代码为准：
- kern/mm/default_pmm.c
- kern/mm/best_fit_pmm.c
- kern/mm/best_fit_pmm.h
- kern/mm/pmm.h
- kern/mm/memlayout.h
- libs/list.h

项目已提供：
- struct Page 和 free_area_t。
- struct pmm_manager 接口。
- 页面状态宏、引用计数接口和双向链表操作。
- 完整的 First-Fit 实现。
- basic_check() 和 best_fit_check() 两个测试函数。

当前 best_fit_pmm.c 只有空闲区状态定义和测试函数。
当前 pmm.c 使用 default_pmm_manager。

[GUARANTEE]

1. 不修改 basic_check() 和 best_fit_check()。
2. 不修改 default_pmm.c、page_init()、评分脚本或测试断言。
3. 不删除既有测试来绕过错误。
4. Best-Fit 的内部状态必须与测试使用的 free_list、
   nr_free 保持一致。
5. 保留 lab2 注释标记，将本次 Best-Fit 实现位置的
   YOUR CODE 替换为我的学号 2414166。
   不修改其他作者的学号。
6. 不实现 Buddy 或 SLUB，不修改实验报告。
7. 如未实际执行测试，明确说明，不能声称测试通过。

[SPECIFICATION]

采用按地址递增排列的空闲块链表。

实现以下功能：
1. 初始化：初始化空闲链表，空闲页数置零。
2. 注册空闲区：初始化页面状态，设置空闲块首页的
   property 和标志，按地址插入，更新空闲页数。
3. 分配：
   - 从所有满足请求的空闲块中选择最小块。
   - 大小相同时选择地址较低的块。
   - 找到完全匹配块时可以提前结束搜索。
   - 无满足要求的连续块时返回 NULL。
   - 必要时拆分，并维护剩余块、状态和页数。
4. 释放：
   - 恢复页面状态，按地址插回链表。
   - 合并前后物理连续的空闲块。
   - 正确维护 property、标志和空闲页数。
5. 实现空闲页数量查询。
6. 定义完整的 best_fit_pmm_manager，
   将检查入口绑定到已有 best_fit_check()。
7. 在 pmm.c 的 init_pmm_manager() 中，
   将当前物理内存管理器切换为 best_fit_pmm_manager。

完成后说明修改位置，并提供编译和运行验证命令。
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
