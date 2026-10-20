#ifndef __KERN_MM_BUDDY_SYSTEM_H__
#define __KERN_MM_BUDDY_SYSTEM_H__

#include <pmm.h>

extern const struct pmm_manager buddy_system_pmm_manager;

/* Run the Buddy manager on an isolated arena, then return it to current PMM. */
void buddy_system_self_check(void);

#endif /* !__KERN_MM_BUDDY_SYSTEM_H__ */
