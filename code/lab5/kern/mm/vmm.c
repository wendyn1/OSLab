#include <vmm.h>
#include <cow.h>
#include <sync.h>
#include <string.h>
#include <assert.h>
#include <stdio.h>
#include <error.h>
#include <pmm.h>
#include <riscv.h>
#include <kmalloc.h>

/*
  vmm design include two parts: mm_struct (mm) & vma_struct (vma)
  mm is the memory manager for the set of continuous virtual memory
  area which have the same PDT. vma is a continuous virtual memory area.
  There a linear link list for vma & a redblack link list for vma in mm.
---------------
  mm related functions:
   golbal functions
     struct mm_struct * mm_create(void)
     void mm_destroy(struct mm_struct *mm)
     int do_pgfault(struct mm_struct *mm, uint32_t error_code, uintptr_t addr)
--------------
  vma related functions:
   global functions
     struct vma_struct * vma_create (uintptr_t vm_start, uintptr_t vm_end,...)
     void insert_vma_struct(struct mm_struct *mm, struct vma_struct *vma)
     struct vma_struct * find_vma(struct mm_struct *mm, uintptr_t addr)
   local functions
     inline void check_vma_overlap(struct vma_struct *prev, struct vma_struct *next)
---------------
   check correctness functions
     void check_vmm(void);
     void check_vma_struct(void);
     void check_pgfault(void);
*/

static void check_vmm(void);
static void check_vma_struct(void);

// mm_create -  alloc a mm_struct & initialize it.
struct mm_struct *
mm_create(void)
{
    struct mm_struct *mm = kmalloc(sizeof(struct mm_struct));

    if (mm != NULL)
    {
        list_init(&(mm->mmap_list));
        mm->mmap_cache = NULL;
        mm->pgdir = NULL;
        mm->map_count = 0;

        mm->sm_priv = NULL;

        set_mm_count(mm, 0);
        lock_init(&(mm->mm_lock));
    }
    return mm;
}

// vma_create - alloc a vma_struct & initialize it. (addr range: vm_start~vm_end)
struct vma_struct *
vma_create(uintptr_t vm_start, uintptr_t vm_end, uint32_t vm_flags)
{
    struct vma_struct *vma = kmalloc(sizeof(struct vma_struct));

    if (vma != NULL)
    {
        vma->vm_start = vm_start;
        vma->vm_end = vm_end;
        vma->vm_flags = vm_flags;
    }
    return vma;
}

// find_vma - find a vma  (vma->vm_start <= addr <= vma_vm_end)
struct vma_struct *
find_vma(struct mm_struct *mm, uintptr_t addr)
{
    struct vma_struct *vma = NULL;
    if (mm != NULL)
    {
        vma = mm->mmap_cache;
        if (!(vma != NULL && vma->vm_start <= addr && vma->vm_end > addr))
        {
            bool found = 0;
            list_entry_t *list = &(mm->mmap_list), *le = list;
            while ((le = list_next(le)) != list)
            {
                vma = le2vma(le, list_link);
                if (vma->vm_start <= addr && addr < vma->vm_end)
                {
                    found = 1;
                    break;
                }
            }
            if (!found)
            {
                vma = NULL;
            }
        }
        if (vma != NULL)
        {
            mm->mmap_cache = vma;
        }
    }
    return vma;
}

// check_vma_overlap - check if vma1 overlaps vma2 ?
static inline void
check_vma_overlap(struct vma_struct *prev, struct vma_struct *next)
{
    assert(prev->vm_start < prev->vm_end);
    assert(prev->vm_end <= next->vm_start);
    assert(next->vm_start < next->vm_end);
}

// insert_vma_struct -insert vma in mm's list link
void insert_vma_struct(struct mm_struct *mm, struct vma_struct *vma)
{
    assert(vma->vm_start < vma->vm_end);
    list_entry_t *list = &(mm->mmap_list);
    list_entry_t *le_prev = list, *le_next;

    list_entry_t *le = list;
    while ((le = list_next(le)) != list)
    {
        struct vma_struct *mmap_prev = le2vma(le, list_link);
        if (mmap_prev->vm_start > vma->vm_start)
        {
            break;
        }
        le_prev = le;
    }

    le_next = list_next(le_prev);

    /* check overlap */
    if (le_prev != list)
    {
        check_vma_overlap(le2vma(le_prev, list_link), vma);
    }
    if (le_next != list)
    {
        check_vma_overlap(vma, le2vma(le_next, list_link));
    }

    vma->vm_mm = mm;
    list_add_after(le_prev, &(vma->list_link));

    mm->map_count++;
}

// mm_destroy - free mm and mm internal fields
void mm_destroy(struct mm_struct *mm)
{
    assert(mm_count(mm) == 0);

    list_entry_t *list = &(mm->mmap_list), *le;
    while ((le = list_next(list)) != list)
    {
        list_del(le);
        kfree(le2vma(le, list_link)); // kfree vma
    }
    kfree(mm); // kfree mm
    mm = NULL;
}

int mm_map(struct mm_struct *mm, uintptr_t addr, size_t len, uint32_t vm_flags,
           struct vma_struct **vma_store)
{
    uintptr_t start = ROUNDDOWN(addr, PGSIZE), end = ROUNDUP(addr + len, PGSIZE);
    if (!USER_ACCESS(start, end))
    {
        return -E_INVAL;
    }

    assert(mm != NULL);

    int ret = -E_INVAL;

    struct vma_struct *vma;
    if ((vma = find_vma(mm, start)) != NULL && end > vma->vm_start)
    {
        goto out;
    }
    ret = -E_NO_MEM;

    if ((vma = vma_create(start, end, vm_flags)) == NULL)
    {
        goto out;
    }
    insert_vma_struct(mm, vma);
    if (vma_store != NULL)
    {
        *vma_store = vma;
    }
    ret = 0;

out:
    return ret;
}

//lab5 function3 2411061
#ifdef LAB5_COPY_SELFTEST
// 2411061：只在显式自检构建运行；测试页表不发布给调度器，不改变正式用户映像。
static void lab5_copy_selfcheck(void)
{
    static bool done;
    if (done) return;
    done = 1;
    const uintptr_t va = 0x400000;
    struct mm_struct *src = mm_create(), *dst = mm_create();
    assert(src != NULL && dst != NULL);
    struct Page *sr = alloc_page(), *dr = alloc_page();
    assert(sr != NULL && dr != NULL);
    src->pgdir = page2kva(sr); dst->pgdir = page2kva(dr);
    memcpy(src->pgdir, boot_pgdir_va, PGSIZE);
    memcpy(dst->pgdir, boot_pgdir_va, PGSIZE);
    assert(mm_map(src, va, PGSIZE * 2, VM_READ | VM_WRITE, NULL) == 0);
    assert(mm_map(dst, va, PGSIZE * 2, VM_READ | VM_WRITE, NULL) == 0);
    assert(mm_map(src, va + PGSIZE * 2, PGSIZE, VM_READ, NULL) == 0);
    assert(mm_map(dst, va + PGSIZE * 2, PGSIZE, VM_READ, NULL) == 0);
    struct Page *data = pgdir_alloc_page(src->pgdir, va, PTE_U | PTE_R | PTE_W);
    struct Page *ro = pgdir_alloc_page(src->pgdir, va + PGSIZE * 2, PTE_U | PTE_R);
    assert(data != NULL && ro != NULL);
    memset(page2kva(data), 0x35, PGSIZE);
    memset(page2kva(ro), 0x67, PGSIZE);
#ifdef LAB5_COW
    assert(cow_copy_range(dst->pgdir, src->pgdir, va, va + PGSIZE * 3) == 0);
    assert(get_page(dst->pgdir, va, NULL) == data && page_ref(data) == 2);
    assert((*get_pte(src->pgdir, va, 0) & (PTE_W | 0x100)) == 0x100);
    assert(cow_resolve_write(dst, va) == 0);
    struct Page *copy = get_page(dst->pgdir, va, NULL);
    assert(copy != data && page_ref(data) == 1);
    assert(memcmp(page2kva(copy), page2kva(data), PGSIZE) == 0);
    memset(page2kva(copy), 0x48, PGSIZE);
    assert(*(unsigned char *)page2kva(data) == 0x35);
    assert(cow_resolve_write(src, va) == 0);
    assert(get_page(src->pgdir, va, NULL) == data); // 单引用恢复不额外复制。
    cprintf("[C selfcheck] COW share/split/single-reference PASS\n");

    pte_t *entry = get_pte(dst->pgdir, va + PGSIZE * 2, 0);
    assert(!(*entry & (PTE_W | 0x100)));
    pte_t saved = *entry;
    // 受控模拟错误授权：只看软件标记就放宽硬件权限会越过只读 VMA；立即还原。
    *entry |= 0x100 | PTE_W;
    assert((*entry & PTE_W) && !user_mem_check(dst, va + PGSIZE * 2, 1, 1));
    *entry = saved | 0x100;
    assert(cow_resolve_write(dst, va + PGSIZE * 2) == -E_FAULT);
    assert(*entry == (saved | 0x100) && page_ref(ro) == 2);
    *entry = saved;
    cprintf("[C selfcheck] readonly authorization fault injection rejected PASS\n");
#else
    assert(copy_range(dst->pgdir, src->pgdir, va, va + PGSIZE * 3, 0) == 0);
    struct Page *copy = get_page(dst->pgdir, va, NULL);
    assert(copy != NULL && copy != data && page_ref(copy) == 1 && page_ref(data) == 1);
    assert(memcmp(page2kva(copy), page2kva(data), PGSIZE) == 0);
    memset(page2kva(copy), 0x48, PGSIZE);
    assert(*(unsigned char *)page2kva(data) == 0x35);
    assert(!(*get_pte(dst->pgdir, va + PGSIZE * 2, 0) & PTE_W));
    cprintf("[C selfcheck] eager copy physical independence/permissions PASS\n");
#endif
    assert(get_page(dst->pgdir, va + PGSIZE, NULL) == NULL);
    exit_mmap(dst); exit_mmap(src);
    free_page(dr); free_page(sr);
    mm_destroy(dst); mm_destroy(src);
    cprintf("[C selfcheck] sparse range and cleanup PASS\n");
}
#endif

int dup_mmap(struct mm_struct *to, struct mm_struct *from)
{
#ifdef LAB5_COPY_SELFTEST
    lab5_copy_selfcheck();
#endif
    assert(to != NULL && from != NULL && to != from);
    list_entry_t *head = &from->mmap_list, *le = head;
    while ((le = list_next(le)) != head) {
        struct vma_struct *src = le2vma(le, list_link);
        struct vma_struct *dst = vma_create(src->vm_start, src->vm_end, src->vm_flags);
        if (dst == NULL) return -E_NO_MEM;
        insert_vma_struct(to, dst); // 先登记 VMA，让调用者能清理部分复制的映射。
#ifdef LAB5_COW
        // A 的扩展通过显式构建开关接入，默认保留 C 的逐页深复制基线。
        int ret = cow_copy_range(to->pgdir, from->pgdir, src->vm_start, src->vm_end);
#else
        int ret = copy_range(to->pgdir, from->pgdir, src->vm_start, src->vm_end, 0);
#endif
        if (ret != 0) return ret;
    }
    return 0;
}



void exit_mmap(struct mm_struct *mm)
{
    assert(mm != NULL && mm_count(mm) == 0);
    pde_t *pgdir = mm->pgdir;
    list_entry_t *list = &(mm->mmap_list), *le = list;
    while ((le = list_next(le)) != list)
    {
        struct vma_struct *vma = le2vma(le, list_link);
        unmap_range(pgdir, vma->vm_start, vma->vm_end);
    }
    while ((le = list_next(le)) != list)
    {
        struct vma_struct *vma = le2vma(le, list_link);
        exit_range(pgdir, vma->vm_start, vma->vm_end);
    }
}

bool copy_from_user(struct mm_struct *mm, void *dst, const void *src, size_t len, bool writable)
{
    if (!user_mem_check(mm, (uintptr_t)src, len, writable))
    {
        return 0;
    }
    memcpy(dst, src, len);
    return 1;
}

bool copy_to_user(struct mm_struct *mm, void *dst, const void *src, size_t len)
{
    if (!cow_prepare_user_write(mm, (uintptr_t)dst, len))
    {
        return 0;
    }
    memcpy(dst, src, len);
    return 1;
}

// vmm_init - initialize virtual memory management
//          - now just call check_vmm to check correctness of vmm
void vmm_init(void)
{
    check_vmm();
}

// check_vmm - check correctness of vmm
static void
check_vmm(void)
{
    // size_t nr_free_pages_store = nr_free_pages();

    check_vma_struct();
    // check_pgfault();

    cprintf("check_vmm() succeeded.\n");
}

static void
check_vma_struct(void)
{
    // size_t nr_free_pages_store = nr_free_pages();

    struct mm_struct *mm = mm_create();
    assert(mm != NULL);

    int step1 = 10, step2 = step1 * 10;

    int i;
    for (i = step1; i >= 1; i--)
    {
        struct vma_struct *vma = vma_create(i * 5, i * 5 + 2, 0);
        assert(vma != NULL);
        insert_vma_struct(mm, vma);
    }

    for (i = step1 + 1; i <= step2; i++)
    {
        struct vma_struct *vma = vma_create(i * 5, i * 5 + 2, 0);
        assert(vma != NULL);
        insert_vma_struct(mm, vma);
    }

    list_entry_t *le = list_next(&(mm->mmap_list));

    for (i = 1; i <= step2; i++)
    {
        assert(le != &(mm->mmap_list));
        struct vma_struct *mmap = le2vma(le, list_link);
        assert(mmap->vm_start == i * 5 && mmap->vm_end == i * 5 + 2);
        le = list_next(le);
    }

    for (i = 5; i <= 5 * step2; i += 5)
    {
        struct vma_struct *vma1 = find_vma(mm, i);
        assert(vma1 != NULL);
        struct vma_struct *vma2 = find_vma(mm, i + 1);
        assert(vma2 != NULL);
        struct vma_struct *vma3 = find_vma(mm, i + 2);
        assert(vma3 == NULL);
        struct vma_struct *vma4 = find_vma(mm, i + 3);
        assert(vma4 == NULL);
        struct vma_struct *vma5 = find_vma(mm, i + 4);
        assert(vma5 == NULL);

        assert(vma1->vm_start == i && vma1->vm_end == i + 2);
        assert(vma2->vm_start == i && vma2->vm_end == i + 2);
    }

    for (i = 4; i >= 0; i--)
    {
        struct vma_struct *vma_below_5 = find_vma(mm, i);
        if (vma_below_5 != NULL)
        {
            cprintf("vma_below_5: i %x, start %x, end %x\n", i, vma_below_5->vm_start, vma_below_5->vm_end);
        }
        assert(vma_below_5 == NULL);
    }

    mm_destroy(mm);

    cprintf("check_vma_struct() succeeded!\n");
}
bool user_mem_check(struct mm_struct *mm, uintptr_t addr, size_t len, bool write)
{
    if (mm != NULL)
    {
        if (!USER_ACCESS(addr, addr + len))
        {
            return 0;
        }
        struct vma_struct *vma;
        uintptr_t start = addr, end = addr + len;
        while (start < end)
        {
            if ((vma = find_vma(mm, start)) == NULL || start < vma->vm_start)
            {
                return 0;
            }
            if (!(vma->vm_flags & ((write) ? VM_WRITE : VM_READ)))
            {
                return 0;
            }
            if (write && (vma->vm_flags & VM_STACK))
            {
                if (start < vma->vm_start + PGSIZE)
                { // check stack start & size
                    return 0;
                }
            }
            start = vma->vm_end;
        }
        return 1;
    }
    return KERN_ACCESS(addr, addr + len);
}
