#include <assert.h>
#include <cow.h>
#include <error.h>
#include <pmm.h>
#include <string.h>
#include <sync.h>
#include <vmm.h>

/* lab5 Challenge 2414166. RSW bit 8 marks a formerly writable leaf. */
#define PTE_COW 0x100

int cow_copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end) {
    assert(to != from && start % PGSIZE == 0 && end % PGSIZE == 0);
    assert(USER_ACCESS(start, end));
    bool intr_flag;
    local_intr_save(intr_flag);
    int ret = 0;
    for (uintptr_t va = start; va < end; va += PGSIZE) {
        pte_t *entry = get_pte(from, va, 0);
        if (entry == NULL || (*entry & (PTE_V | PTE_U)) != (PTE_V | PTE_U)) {
            continue;
        }

        pte_t original = *entry;
        uint32_t perm = original & (PTE_USER | PTE_A | PTE_D | PTE_COW);
        if (perm & PTE_W) {
            perm = (perm & ~PTE_W) | PTE_COW;
        }
        ret = page_insert(to, pte2page(original), va, perm);
        if (ret != 0) {
            break;  // The caller discards the incomplete child.
        }
        if (original & PTE_W) {
            *entry = (original & ~PTE_W) | PTE_COW;
            tlb_invalidate(from, va);
        }
    }
    local_intr_restore(intr_flag);
    return ret;
}

int cow_resolve_write(struct mm_struct *mm, uintptr_t addr) {
    bool intr_flag;
    local_intr_save(intr_flag);
    int ret = -E_FAULT;
    if (mm == NULL || mm->pgdir == NULL || !user_mem_check(mm, addr, 1, 1)) {
        goto out;
    }
    uintptr_t va = ROUNDDOWN(addr, PGSIZE);
    pte_t *entry = get_pte(mm->pgdir, va, 0);
    if (entry == NULL || (*entry & (PTE_V | PTE_U | PTE_COW | PTE_W)) !=
                                     (PTE_V | PTE_U | PTE_COW)) {
        goto out;
    }

    struct Page *old = pte2page(*entry);
    if (page_ref(old) == 1) {
        *entry = (*entry | PTE_W) & ~PTE_COW;
        tlb_invalidate(mm->pgdir, va);
        ret = 0;
    } else {
        struct Page *fresh = alloc_page();
        if (fresh == NULL) {
            ret = -E_NO_MEM;
            goto out;
        }
        memcpy(page2kva(fresh), page2kva(old), PGSIZE);
        uint32_t perm = (*entry & (PTE_USER | PTE_A | PTE_D)) | PTE_W;
        ret = page_insert(mm->pgdir, fresh, va, perm);
        if (ret != 0) {
            free_page(fresh);
        }
    }
out:
    local_intr_restore(intr_flag);
    return ret;
}

bool cow_prepare_user_write(struct mm_struct *mm, uintptr_t addr, size_t len) {
    if (!user_mem_check(mm, addr, len, 1)) {
        return 0;
    }
    if (mm == NULL || len == 0) {
        return 1;
    }
    if (mm->pgdir == NULL) {
        return 0;
    }
    for (uintptr_t pos = addr; pos < addr + len; ) {
        pte_t *entry = get_pte(mm->pgdir, pos, 0);
        if (entry == NULL || (*entry & (PTE_V | PTE_U)) != (PTE_V | PTE_U)) {
            return 0;
        }
        if (!(*entry & PTE_W) && cow_resolve_write(mm, pos) != 0) {
            return 0;
        }
        pos = ROUNDDOWN(pos, PGSIZE) + PGSIZE;
    }
    return 1;
}
