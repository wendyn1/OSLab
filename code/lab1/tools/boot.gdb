set pagination off
set confirm off
set architecture riscv:rv64
file bin/kernel
target remote 127.0.0.1:1234
echo === RESET ===\n
info registers pc sp a0 a1 a2
x/6i 0x1000
x/4gx 0x1018
echo === KERNEL BYTES BEFORE CPU RUNS ===\n
x/4i 0x80200000
hbreak *0x80000000
continue
echo === OPENSBI ENTRY ===\n
info registers pc a0 a1 a2
p/x $priv
hbreak *0x80200000
continue
echo === KERNEL ENTRY ===\n
info registers pc sp ra a0 a1
p/x $priv
x/6i $pc
p/x &bootstack
p/x &bootstacktop
si
si
echo === STACK INITIALIZED ===\n
info registers pc sp
si
echo === TAIL TO C ===\n
info registers pc sp ra
x/i $pc
detach
quit
