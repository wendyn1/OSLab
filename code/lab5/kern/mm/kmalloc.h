#ifndef __KERN_MM_KMALLOC_H__
#define __KERN_MM_KMALLOC_H__

#include <defs.h>

#define KMALLOC_MAX_ORDER 10

void kmalloc_init(void);

void *kmalloc(size_t n);
void kfree(void *objp);

size_t kallocated(void);
// 2411061：实验收尾时归还 SLOB 中完整空闲页，不影响仍存活对象。
void kmalloc_trim(void);

#endif /* !__KERN_MM_KMALLOC_H__ */
