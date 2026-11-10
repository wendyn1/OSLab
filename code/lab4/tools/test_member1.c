// LAB4 function1 tests 2414166 滕鑫
// Appended only to a temporary test kernel by test_member1.py.
#include <error.h>

static const struct pmm_manager *saved_manager;
static int allocation_budget;

static struct Page *limited_alloc(size_t n)
{
    if (allocation_budget == 0)
        return NULL;
    allocation_budget--;
    return saved_manager->alloc_pages(n);
}

static void check_insert_failure(pde_t *pgdir, struct Page *page,
                                 uintptr_t la, int budget)
{
    struct pmm_manager limited = *pmm_manager;
    size_t before = nr_free_pages();
    pde_t root_before = pgdir[PDX1(la)];
    int ref_before = page_ref(page);
    saved_manager = pmm_manager;
    limited.alloc_pages = limited_alloc;
    allocation_budget = budget;
    pmm_manager = &limited;
    assert(page_insert(pgdir, page, la, PTE_R | PTE_W) == -E_NO_MEM);
    pmm_manager = saved_manager;
    assert(nr_free_pages() == before);
    assert(page_ref(page) == ref_before);
    assert(pgdir[PDX1(la)] == root_before);
    assert(get_page(pgdir, la, NULL) == NULL);
}

static void member1_mapping_tests(void)
{
    size_t before = nr_free_pages();
    struct Page *root = alloc_page(), *a = alloc_page(), *b = alloc_page();
    assert(root != NULL && a != NULL && b != NULL);
    pde_t *pgdir = page2kva(root);
    memset(pgdir, 0, PGSIZE);

    page_remove(pgdir, 0);
    assert(pgdir[0] == 0); // An absent path must not allocate tables.
    check_insert_failure(pgdir, a, 0, 0);
    check_insert_failure(pgdir, a, 0, 1); // Roll back the first new table.
    cprintf("[Member1] allocation failure and rollback PASS\n");

    assert(page_insert(pgdir, a, 0x100, PTE_R | PTE_W | PTE_U) == 0);
    pte_t *ptep = get_pte(pgdir, 0, 0);
    assert(ptep != NULL && page_ref(a) == 1);
    assert(PTE_ADDR(*ptep) == page2pa(a));
    size_t stable = nr_free_pages();
    assert(page_insert(pgdir, a, 0, PTE_R) == 0);
    assert(page_ref(a) == 1 && nr_free_pages() == stable);
    assert((*ptep & (PTE_U | PTE_W | PTE_R)) == PTE_R);
    assert(page_insert(pgdir, a, PGSIZE, PTE_R | PTE_W) == 0);
    assert(page_ref(a) == 2);
    assert(page_insert(pgdir, b, 0, PTE_R | PTE_W) == 0);
    assert(page_ref(a) == 1 && page_ref(b) == 1);
    assert(get_page(pgdir, 0, NULL) == b);
    check_insert_failure(pgdir, b, PTSIZE, 0); // Preserve existing parent.
    assert(get_page(pgdir, 0, NULL) == b && page_ref(b) == 1);
    cprintf("[Member1] same-page remap, permissions, aliases, replacement PASS\n");

    page_remove(pgdir, PGSIZE);
    assert(page_ref(a) == 0 && get_page(pgdir, PGSIZE, NULL) == NULL);
    page_remove(pgdir, 0);
    assert(page_ref(b) == 0 && *ptep == 0);
    stable = nr_free_pages();
    page_remove(pgdir, 0);
    page_remove(pgdir, 2 * PGSIZE); // An allocated table with an absent PTE.
    assert(nr_free_pages() == stable);
    pde_t *middle = KADDR(PDE_ADDR(pgdir[0]));
    struct Page *leaf_table = pde2page(middle[0]);
    struct Page *middle_table = pde2page(pgdir[0]);
    set_page_ref(leaf_table, 0);
    free_page(leaf_table);
    set_page_ref(middle_table, 0);
    free_page(middle_table);
    free_page(root);
    assert(nr_free_pages() == before);
    cprintf("[Member1] idempotent removal and free-page accounting PASS\n");

    // Exercise translations on the active page table, not just PTE values.
    uintptr_t la = (uintptr_t)1 << PDX1SHIFT;
    assert(boot_pgdir_va[PDX1(la)] == 0);
    a = alloc_page();
    b = alloc_page();
    assert(a != NULL && b != NULL);
    *(volatile unsigned long *)page2kva(a) = 0x11223344UL;
    *(volatile unsigned long *)page2kva(b) = 0x55667788UL;
    assert(page_insert(boot_pgdir_va, a, la, PTE_R | PTE_W) == 0);
    assert(*(volatile unsigned long *)la == 0x11223344UL);
    assert(page_insert(boot_pgdir_va, b, la, PTE_R | PTE_W) == 0);
    assert(*(volatile unsigned long *)la == 0x55667788UL);
    page_remove(boot_pgdir_va, la);
    a = alloc_page();
    assert(a != NULL);
    *(volatile unsigned long *)page2kva(a) = 0xaabbccddUL;
    assert(page_insert(boot_pgdir_va, a, la, PTE_R | PTE_W) == 0);
    assert(*(volatile unsigned long *)la == 0xaabbccddUL);
    page_remove(boot_pgdir_va, la);
    middle = KADDR(PDE_ADDR(boot_pgdir_va[PDX1(la)]));
    leaf_table = pde2page(middle[0]);
    middle_table = pde2page(boot_pgdir_va[PDX1(la)]);
    middle[0] = 0;
    boot_pgdir_va[PDX1(la)] = 0;
    flush_tlb();
    set_page_ref(leaf_table, 0);
    free_page(leaf_table);
    set_page_ref(middle_table, 0);
    free_page(middle_table);
    assert(nr_free_pages() == before);
    cprintf("[Member1] active mapping replacement and TLB invalidation PASS\n");
}
