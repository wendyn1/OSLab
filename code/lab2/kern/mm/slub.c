#include <assert.h>
#include <mmu.h>
#include <pmm.h>
#include <slub.h>
#include <stdio.h>

// Lab2 Challenge 2410721: simplified two-layer SLUB allocator.
#define SLUB_MAGIC 0x534c5542U
#define SLUB_CACHE_COUNT 9
#define SLUB_MAX_OBJECT_SIZE 2048

struct slub_free_object {
    struct slub_free_object *next;
};

struct slub_cache;

struct slub_slab {
    uint32_t magic;
    uint16_t inuse;
    uint16_t total;
    struct slub_cache *cache;
    struct slub_free_object *free;
    struct slub_slab *next;
};

struct slub_cache {
    size_t object_size;
    struct slub_slab *slabs;
};

static const size_t slub_sizes[SLUB_CACHE_COUNT] = {
    8, 16, 32, 64, 128, 256, 512, 1024, 2048,
};
static struct slub_cache slub_caches[SLUB_CACHE_COUNT];
static bool slub_initialized;

static uintptr_t
slub_page_to_kva(struct Page *page) {
    return page2pa(page) + va_pa_offset;
}

static size_t
slub_object_offset(void) {
    size_t alignment = sizeof(void *);
    return (sizeof(struct slub_slab) + alignment - 1) & ~(alignment - 1);
}

static struct slub_cache *
slub_find_cache(size_t size) {
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i++) {
        if (size <= slub_caches[i].object_size) {
            return &slub_caches[i];
        }
    }
    return NULL;
}

static struct slub_slab *
slub_grow(struct slub_cache *cache) {
    struct Page *page = alloc_page();
    if (page == NULL) {
        return NULL;
    }

    struct slub_slab *slab = (struct slub_slab *)slub_page_to_kva(page);
    size_t offset = slub_object_offset();
    size_t count = (PGSIZE - offset) / cache->object_size;
    assert(count > 0 && count <= 0xffff);

    slab->magic = SLUB_MAGIC;
    slab->inuse = 0;
    slab->total = count;
    slab->cache = cache;
    slab->free = NULL;
    slab->next = cache->slabs;
    cache->slabs = slab;

    uintptr_t start = (uintptr_t)slab + offset;
    for (size_t i = count; i > 0; i--) {
        struct slub_free_object *obj =
            (struct slub_free_object *)(start + (i - 1) * cache->object_size);
        obj->next = slab->free;
        slab->free = obj;
    }
    return slab;
}

static void
slub_release_empty(struct slub_slab *slab) {
    struct slub_cache *cache = slab->cache;
    struct slub_slab **link = &cache->slabs;
    while (*link != NULL && *link != slab) {
        link = &(*link)->next;
    }
    assert(*link == slab);
    *link = slab->next;
    slab->magic = 0;

    uintptr_t pa = (uintptr_t)slab - va_pa_offset;
    free_page(pa2page(pa));
}

void
slub_init(void) {
    for (size_t i = 0; i < SLUB_CACHE_COUNT; i++) {
        slub_caches[i].object_size = slub_sizes[i];
        slub_caches[i].slabs = NULL;
    }
    slub_initialized = 1;
}

void *
slub_alloc(size_t size) {
    if (!slub_initialized || size == 0 || size > SLUB_MAX_OBJECT_SIZE) {
        return NULL;
    }

    struct slub_cache *cache = slub_find_cache(size);
    assert(cache != NULL);
    struct slub_slab *slab = cache->slabs;
    while (slab != NULL && slab->free == NULL) {
        slab = slab->next;
    }
    if (slab == NULL && (slab = slub_grow(cache)) == NULL) {
        return NULL;
    }

    struct slub_free_object *obj = slab->free;
    slab->free = obj->next;
    slab->inuse++;
    assert(slab->inuse <= slab->total);
    return obj;
}

void
slub_free(void *obj) {
    if (obj == NULL) {
        return;
    }

    struct slub_slab *slab =
        (struct slub_slab *)ROUNDDOWN((uintptr_t)obj, PGSIZE);
    assert(slab->magic == SLUB_MAGIC && slab->cache != NULL);

    size_t offset = slub_object_offset();
    uintptr_t first = (uintptr_t)slab + offset;
    uintptr_t address = (uintptr_t)obj;
    size_t object_size = slab->cache->object_size;
    assert(address >= first && address < (uintptr_t)slab + PGSIZE);
    assert((address - first) % object_size == 0);
    assert((address - first) / object_size < slab->total);

    for (struct slub_free_object *p = slab->free; p != NULL; p = p->next) {
        assert(p != obj);
    }

    struct slub_free_object *free_obj = obj;
    free_obj->next = slab->free;
    slab->free = free_obj;
    assert(slab->inuse > 0);
    slab->inuse--;

    if (slab->inuse == 0) {
        slub_release_empty(slab);
    }
}

void
slub_check(void) {
    size_t free_before = nr_free_pages();
    void *objects[96];

    assert(slub_alloc(0) == NULL);
    assert(slub_alloc(SLUB_MAX_OBJECT_SIZE + 1) == NULL);
    slub_free(NULL);

    size_t requests[] = {1, 8, 9, 24, 63, 64, 65, 255, 511, 1024, 2000};
    size_t request_count = sizeof(requests) / sizeof(requests[0]);
    for (size_t i = 0; i < request_count; i++) {
        objects[i] = slub_alloc(requests[i]);
        assert(objects[i] != NULL);
        unsigned char *bytes = objects[i];
        for (size_t j = 0; j < requests[i]; j++) {
            bytes[j] = (unsigned char)(0x30 + i);
        }
    }
    for (size_t i = 0; i < request_count; i++) {
        unsigned char *bytes = objects[i];
        for (size_t j = 0; j < requests[i]; j++) {
            assert(bytes[j] == (unsigned char)(0x30 + i));
        }
    }

    for (size_t i = request_count; i < 96; i++) {
        objects[i] = slub_alloc(64);
        assert(objects[i] != NULL);
        *(uint64_t *)objects[i] = i;
    }
    for (size_t i = request_count; i < 96; i += 2) {
        slub_free(objects[i]);
        objects[i] = NULL;
    }
    for (size_t i = request_count; i < 96; i += 2) {
        objects[i] = slub_alloc(64);
        assert(objects[i] != NULL);
    }

    for (size_t i = 0; i < 96; i++) {
        slub_free(objects[i]);
    }
    assert(nr_free_pages() == free_before);
    cprintf("slub_check() succeeded!\n");
}
