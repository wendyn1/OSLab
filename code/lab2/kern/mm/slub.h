#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

/*
 * A compact SLUB-style object allocator for Lab2.
 * Small objects are served from size-class caches backed by physical pages.
 */
void slub_init(void);
void *slub_alloc(size_t size);
void slub_free(void *obj);
void slub_check(void);

#endif /* !__KERN_MM_SLUB_H__ */
