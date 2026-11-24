#ifndef __KERN_MM_COW_H__
#define __KERN_MM_COW_H__
#include <memlayout.h>

struct mm_struct;

/* For private fork only. The destination is new and is discarded on error. */
int cow_copy_range(pde_t *to, pde_t *from, uintptr_t start, uintptr_t end);
int cow_resolve_write(struct mm_struct *mm, uintptr_t addr);
bool cow_prepare_user_write(struct mm_struct *mm, uintptr_t addr, size_t len);
#endif
