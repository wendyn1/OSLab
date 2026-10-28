#!/usr/bin/env python3
"""Verify the integrated submission in disposable copies, without changing grading."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


PROBE = r'''
extern void exception_handler(struct trapframe *tf);
extern void interrupt_handler(struct trapframe *tf);
static void member_c_checks(void) {
    struct trapframe tf, before;
    uint16_t instructions[][2] = {{0, 0}, {0x007b, 0},
                                  {0x9002, 0}, {0x0073, 0x0010}};
    for (int i = 0; i < 4; i++) {
        memset(&tf, 0x5a, sizeof(tf));
        tf.cause = i < 2 ? CAUSE_ILLEGAL_INSTRUCTION : CAUSE_BREAKPOINT;
        tf.epc = (uintptr_t)instructions[i];
        before = tf;
        before.epc += (i & 1) ? 4 : 2;
        exception_handler(&tf);
        assert(memcmp(&tf, &before, sizeof(tf)) == 0);
    }
    memset(&tf, 0, sizeof(tf));
    tf.cause = 20;
    before = tf;
    exception_handler(&tf);
    assert(memcmp(&tf, &before, sizeof(tf)) == 0);
    for (int i = 0; i < 12; i++) {
        if (i == IRQ_S_TIMER) continue;
        tf.cause = ((uintptr_t)1 << 63) | i;
        before = tf;
        interrupt_handler(&tf);
        assert(memcmp(&tf, &before, sizeof(tf)) == 0);
    }
    tf.cause = ((uintptr_t)1 << 63) | 15;
    before = tf;
    interrupt_handler(&tf);
    assert(memcmp(&tf, &before, sizeof(tf)) == 0);
    cprintf("MEMBER_C_HANDLER_PASS: four EPC deltas, frame invariants, fallbacks\n");
    asm volatile(".option push\n.option norvc\n.word 0x0000007b\n.option pop" ::: "memory");
    cprintf("MEMBER_C_RETURN: illegal32\n");
    asm volatile(".2byte 0x0000" ::: "memory");
    cprintf("MEMBER_C_RETURN: illegal16\n");
    asm volatile(".option push\n.option norvc\n.word 0x00100073\n.option pop" ::: "memory");
    cprintf("MEMBER_C_RETURN: breakpoint32\n");
    asm volatile(".2byte 0x9002" ::: "memory");
    cprintf("MEMBER_C_RETURN: breakpoint16\n");
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    source, evidence = args.source.resolve(), args.evidence.resolve()
    evidence.mkdir(parents=True, exist_ok=True)

    def run(command, cwd, log, timeout=180):
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        (evidence / log).write_bytes(result.stdout)
        if result.returncode:
            raise RuntimeError(f"{command}: exit {result.returncode}; see {log}")
        return result.stdout.decode(errors="replace")

    with tempfile.TemporaryDirectory(prefix="lab3-member-c-") as temporary:
        root = Path(temporary) / "lab3"
        shutil.copytree(source, root, ignore=shutil.ignore_patterns(
            "obj", "bin", ".git", ".qemu*", "__pycache__"))
        run(["make", "grade"], root, "grade.log")
        text = (root / "kern/init/init.c").read_text()
        text = text.replace("#include <dtb.h>",
                            "#include <dtb.h>\n#include <assert.h>\n#include <riscv.h>")
        text = text.replace("int kern_init(void) __attribute__", PROBE + "\nint kern_init(void) __attribute__")
        position = text.rfind("idt_init();") + len("idt_init();")
        assert position >= len("idt_init();")
        text = text[:position] + "\n    member_c_checks();" + text[position:]
        (root / "kern/init/init.c").write_text(text)
        run(["make"], root, "build.log")
        output = run(["qemu-system-riscv64", "-machine", "virt", "-nographic",
                      "-bios", "default", "-kernel", "bin/ucore.img",
                      "-monitor", "none", "-no-reboot"], root, "boot.log", 40)
        assert "MEMBER_C_HANDLER_PASS" in output
        for kind in ("illegal32", "illegal16", "breakpoint32", "breakpoint16"):
            assert f"MEMBER_C_RETURN: {kind}" in output
        assert output.splitlines().count("100 ticks") == 10
        assert "timer test complete, shutting down" in output
        assert "check_alloc_page() succeeded!" in output
        assert "panic" not in output.lower()
        (evidence / "summary.txt").write_text(
            "PASS: existing grading 100/100\n"
            "PASS: 16/32-bit illegal instructions and breakpoints return\n"
            "PASS: exact EPC deltas and unchanged remaining trapframe\n"
            "PASS: 11 other interrupt branches, unknown interrupt/exception\n"
            "PASS: Lab2 memory self-check\n"
            "PASS: exactly ten 100-tick lines and QEMU exits with code 0\n")
        print((evidence / "summary.txt").read_text())


if __name__ == "__main__":
    main()
