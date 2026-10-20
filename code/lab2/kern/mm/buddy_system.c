#include <assert.h>
#include <buddy_system.h>
#include <list.h>
#include <stdio.h>

// Lab2 task 3, 2410721: Buddy System physical-page allocator.
#define BUDDY_MAX_ORDER 20
#define BUDDY_TEST_PAGES 64

static list_entry_t buddy_free_list[BUDDY_MAX_ORDER + 1];
static struct Page *buddy_arena;
static size_t buddy_arena_pages;
static size_t buddy_nr_free;

static size_t
buddy_block_size(unsigned int order) {
    return (size_t)1 << order;
}

static unsigned int
buddy_order_for(size_t n) {
    unsigned int order = 0;
    size_t size = 1;
    while (size < n && order < BUDDY_MAX_ORDER) {
        size <<= 1;
        order++;
    }
    return size < n ? BUDDY_MAX_ORDER + 1 : order;
}

static void
buddy_add_block(struct Page *base, unsigned int order) {
    base->property = buddy_block_size(order);
    SetPageProperty(base);
    list_add(&buddy_free_list[order], &base->page_link);
}

static void
buddy_init(void) {
    for (unsigned int order = 0; order <= BUDDY_MAX_ORDER; order++) {
        list_init(&buddy_free_list[order]);
    }
    buddy_arena = NULL;
    buddy_arena_pages = 0;
    buddy_nr_free = 0;
}

static void
buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0 && buddy_arena == NULL);
    buddy_arena = base;
    buddy_arena_pages = n;

    for (struct Page *p = base; p < base + n; p++) {
        p->flags = p->property = 0;
        set_page_ref(p, 0);
        list_init(&p->page_link);
    }

    size_t index = 0;
    while (index < n) {
        size_t remaining = n - index;
        unsigned int order = BUDDY_MAX_ORDER;
        while (order > 0) {
            size_t size = buddy_block_size(order);
            if (size <= remaining && (index & (size - 1)) == 0) {
                break;
            }
            order--;
        }
        buddy_add_block(base + index, order);
        index += buddy_block_size(order);
    }
    buddy_nr_free = n;
}

static struct Page *
buddy_alloc_pages(size_t n) {
    if (n == 0 || buddy_arena == NULL) {
        return NULL;
    }
    unsigned int wanted = buddy_order_for(n);
    if (wanted > BUDDY_MAX_ORDER) {
        return NULL;
    }
    size_t wanted_size = buddy_block_size(wanted);
    if (wanted_size > buddy_nr_free) {
        return NULL;
    }

    unsigned int order = wanted;
    while (order <= BUDDY_MAX_ORDER && list_empty(&buddy_free_list[order])) {
        order++;
    }
    if (order > BUDDY_MAX_ORDER) {
        return NULL;
    }

    list_entry_t *entry = list_next(&buddy_free_list[order]);
    struct Page *block = le2page(entry, page_link);
    list_del_init(entry);
    ClearPageProperty(block);
    block->property = 0;

    while (order > wanted) {
        order--;
        struct Page *right = block + buddy_block_size(order);
        buddy_add_block(right, order);
    }

    block->property = wanted_size;
    buddy_nr_free -= wanted_size;
    return block;
}

static void
buddy_free_pages(struct Page *base, size_t n) {
    assert(base != NULL && n > 0 && buddy_arena != NULL);
    assert(base >= buddy_arena && base < buddy_arena + buddy_arena_pages);
    size_t block_size = base->property;
    unsigned int order = buddy_order_for(n);
    assert(block_size == buddy_block_size(order));
    assert(base + block_size <= buddy_arena + buddy_arena_pages);

    for (struct Page *p = base; p < base + block_size; p++) {
        assert(!PageReserved(p) && !PageProperty(p));
        p->flags = p->property = 0;
        set_page_ref(p, 0);
        list_init(&p->page_link);
    }
    buddy_nr_free += block_size;

    size_t offset = base - buddy_arena;
    while (order < BUDDY_MAX_ORDER) {
        size_t size = buddy_block_size(order);
        size_t buddy_offset = offset ^ size;
        if (buddy_offset >= buddy_arena_pages) {
            break;
        }
        struct Page *other = buddy_arena + buddy_offset;
        if (!PageProperty(other) || other->property != size) {
            break;
        }
        list_del_init(&other->page_link);
        ClearPageProperty(other);
        other->property = 0;
        if (buddy_offset < offset) {
            base = other;
            offset = buddy_offset;
        }
        order++;
    }
    buddy_add_block(base, order);
}

static size_t
buddy_nr_free_pages(void) {
    return buddy_nr_free;
}

static void
buddy_check(void) {
    size_t free_before = buddy_nr_free_pages();
    assert(free_before >= 32);

    struct Page *one = buddy_alloc_pages(1);
    struct Page *three = buddy_alloc_pages(3);
    struct Page *eight = buddy_alloc_pages(8);
    assert(one != NULL && three != NULL && eight != NULL);
    assert(one->property == 1 && three->property == 4 && eight->property == 8);
    assert(buddy_nr_free_pages() == free_before - 13);
    assert(buddy_alloc_pages(free_before + 1) == NULL);

    buddy_free_pages(one, 1);
    buddy_free_pages(three, 3);
    buddy_free_pages(eight, 8);
    assert(buddy_nr_free_pages() == free_before);

    struct Page *left = buddy_alloc_pages(8);
    struct Page *right = buddy_alloc_pages(8);
    assert(left != NULL && right == left + 8);
    buddy_free_pages(left, 8);
    buddy_free_pages(right, 8);
    struct Page *merged = buddy_alloc_pages(16);
    assert(merged == left);
    buddy_free_pages(merged, 16);
    assert(buddy_nr_free_pages() == free_before);

    cprintf("buddy_system_check() succeeded!\n");
}

const struct pmm_manager buddy_system_pmm_manager = {
    .name = "buddy_system_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};

void
buddy_system_self_check(void) {
    size_t original_free = nr_free_pages();
    struct Page *arena = alloc_pages(BUDDY_TEST_PAGES);
    assert(arena != NULL);

    buddy_init();
    buddy_init_memmap(arena, BUDDY_TEST_PAGES);
    buddy_check();
    assert(buddy_nr_free_pages() == BUDDY_TEST_PAGES);

    for (struct Page *p = arena; p < arena + BUDDY_TEST_PAGES; p++) {
        p->flags = p->property = 0;
        set_page_ref(p, 0);
        list_init(&p->page_link);
    }
    buddy_arena = NULL;
    buddy_arena_pages = buddy_nr_free = 0;
    free_pages(arena, BUDDY_TEST_PAGES);
    assert(nr_free_pages() == original_free);
}
