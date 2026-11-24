#include <stdio.h>
#include <ulib.h>

/* lab5 Challenge 2414166: check both writer orders and waitpid copyout. */
static volatile int value = 14;

int main(void) {
    int status = -1;
    int pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        assert(value == 14);
        value = 23;
        assert(value == 23);
        exit(42);
    }
    assert(waitpid(pid, &status) == 0 && status == 42);
    assert(value == 14);

    pid = fork();
    assert(pid >= 0);
    if (pid == 0) {
        for (int i = 0; i < 8; ++i) {
            yield();
        }
        assert(value == 14);
        exit(43);
    }
    value = 37;
    assert(waitpid(pid, &status) == 0 && status == 43);
    assert(value == 37);
    cprintf("cow isolation pass.\n");
    return 0;
}
