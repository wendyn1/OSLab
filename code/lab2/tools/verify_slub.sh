#!/bin/sh
set -eu

mkdir -p validation
make clean
make -j2

set +e
timeout 12s make qemu > validation/slub_qemu.log 2>&1
status=$?
set -e

if [ "$status" -ne 0 ] && [ "$status" -ne 124 ]; then
    cat validation/slub_qemu.log
    echo "QEMU failed with status $status" >&2
    exit 1
fi

grep -F "memory management: best_fit_pmm_manager" validation/slub_qemu.log >/dev/null
grep -F "check_alloc_page() succeeded!" validation/slub_qemu.log >/dev/null
grep -F "buddy_system_check() succeeded!" validation/slub_qemu.log >/dev/null
grep -F "slub_check() succeeded!" validation/slub_qemu.log >/dev/null

cat validation/slub_qemu.log
echo "PASS: Best-Fit, Buddy System, and SLUB checks completed."
