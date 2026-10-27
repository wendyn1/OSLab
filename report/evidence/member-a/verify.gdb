set pagination off
set confirm off
set architecture riscv:rv64
file bin/kernel
set $completed = 0
set $entered = 0
set $called = 0
set $restored = 0
break *member_a_pre16
commands
silent
set $length = 2
set $before_pc = $pc
set $before_status = $sstatus
set $saved0 = $x0
set $saved1 = $x1
set $saved2 = $x2
set $saved3 = $x3
set $saved4 = $x4
set $saved5 = $x5
set $saved6 = $x6
set $saved7 = $x7
set $saved8 = $x8
set $saved9 = $x9
set $saved10 = $x10
set $saved11 = $x11
set $saved12 = $x12
set $saved13 = $x13
set $saved14 = $x14
set $saved15 = $x15
set $saved16 = $x16
set $saved17 = $x17
set $saved18 = $x18
set $saved19 = $x19
set $saved20 = $x20
set $saved21 = $x21
set $saved22 = $x22
set $saved23 = $x23
set $saved24 = $x24
set $saved25 = $x25
set $saved26 = $x26
set $saved27 = $x27
set $saved28 = $x28
set $saved29 = $x29
set $saved30 = $x30
set $saved31 = $x31
printf "BEFORE length=%d pc=%#lx sp=%#lx status=%#lx\n", $length, $pc, $sp, $sstatus
continue
end
break *member_a_post16
commands
silent
if !($x0 == $saved0)
printf "FAIL: post-return x0\n"
quit 1
end
if !($x1 == $saved1)
printf "FAIL: post-return x1\n"
quit 1
end
if !($x2 == $saved2)
printf "FAIL: post-return x2\n"
quit 1
end
if !($x3 == $saved3)
printf "FAIL: post-return x3\n"
quit 1
end
if !($x4 == $saved4)
printf "FAIL: post-return x4\n"
quit 1
end
if !($x5 == $saved5)
printf "FAIL: post-return x5\n"
quit 1
end
if !($x6 == $saved6)
printf "FAIL: post-return x6\n"
quit 1
end
if !($x7 == $saved7)
printf "FAIL: post-return x7\n"
quit 1
end
if !($x8 == $saved8)
printf "FAIL: post-return x8\n"
quit 1
end
if !($x9 == $saved9)
printf "FAIL: post-return x9\n"
quit 1
end
if !($x10 == $saved10)
printf "FAIL: post-return x10\n"
quit 1
end
if !($x11 == $saved11)
printf "FAIL: post-return x11\n"
quit 1
end
if !($x12 == $saved12)
printf "FAIL: post-return x12\n"
quit 1
end
if !($x13 == $saved13)
printf "FAIL: post-return x13\n"
quit 1
end
if !($x14 == $saved14)
printf "FAIL: post-return x14\n"
quit 1
end
if !($x15 == $saved15)
printf "FAIL: post-return x15\n"
quit 1
end
if !($x16 == $saved16)
printf "FAIL: post-return x16\n"
quit 1
end
if !($x17 == $saved17)
printf "FAIL: post-return x17\n"
quit 1
end
if !($x18 == $saved18)
printf "FAIL: post-return x18\n"
quit 1
end
if !($x19 == $saved19)
printf "FAIL: post-return x19\n"
quit 1
end
if !($x20 == $saved20)
printf "FAIL: post-return x20\n"
quit 1
end
if !($x21 == $saved21)
printf "FAIL: post-return x21\n"
quit 1
end
if !($x22 == $saved22)
printf "FAIL: post-return x22\n"
quit 1
end
if !($x23 == $saved23)
printf "FAIL: post-return x23\n"
quit 1
end
if !($x24 == $saved24)
printf "FAIL: post-return x24\n"
quit 1
end
if !($x25 == $saved25)
printf "FAIL: post-return x25\n"
quit 1
end
if !($x26 == $saved26)
printf "FAIL: post-return x26\n"
quit 1
end
if !($x27 == $saved27)
printf "FAIL: post-return x27\n"
quit 1
end
if !($x28 == $saved28)
printf "FAIL: post-return x28\n"
quit 1
end
if !($x29 == $saved29)
printf "FAIL: post-return x29\n"
quit 1
end
if !($x30 == $saved30)
printf "FAIL: post-return x30\n"
quit 1
end
if !($x31 == $saved31)
printf "FAIL: post-return x31\n"
quit 1
end
if !($pc == $before_pc + $length)
printf "FAIL: post-return PC\n"
quit 1
end
if !(($sstatus & 2) == ($before_status & 2))
printf "FAIL: post-return SIE\n"
quit 1
end
printf "POST_SRET status=%#lx (SPP=%d SPIE=%d)\n", $sstatus, ($sstatus >> 8) & 1, ($sstatus >> 5) & 1
if !((($sstatus >> 5) & 1) == 0 && ($sstatus & 0x100) == 0)
printf "FAIL: sret SPP and version-specific SPIE\n"
quit 1
end
set $completed = $completed + 1
printf "AFTER PASS: all 32 GPR slots, sp, PC, SIE; count=%d status=%#lx\n", $completed, $sstatus
continue
end
break *member_a_pre32
commands
silent
set $length = 4
set $before_pc = $pc
set $before_status = $sstatus
set $saved0 = $x0
set $saved1 = $x1
set $saved2 = $x2
set $saved3 = $x3
set $saved4 = $x4
set $saved5 = $x5
set $saved6 = $x6
set $saved7 = $x7
set $saved8 = $x8
set $saved9 = $x9
set $saved10 = $x10
set $saved11 = $x11
set $saved12 = $x12
set $saved13 = $x13
set $saved14 = $x14
set $saved15 = $x15
set $saved16 = $x16
set $saved17 = $x17
set $saved18 = $x18
set $saved19 = $x19
set $saved20 = $x20
set $saved21 = $x21
set $saved22 = $x22
set $saved23 = $x23
set $saved24 = $x24
set $saved25 = $x25
set $saved26 = $x26
set $saved27 = $x27
set $saved28 = $x28
set $saved29 = $x29
set $saved30 = $x30
set $saved31 = $x31
printf "BEFORE length=%d pc=%#lx sp=%#lx status=%#lx\n", $length, $pc, $sp, $sstatus
continue
end
break *member_a_post32
commands
silent
if !($x0 == $saved0)
printf "FAIL: post-return x0\n"
quit 1
end
if !($x1 == $saved1)
printf "FAIL: post-return x1\n"
quit 1
end
if !($x2 == $saved2)
printf "FAIL: post-return x2\n"
quit 1
end
if !($x3 == $saved3)
printf "FAIL: post-return x3\n"
quit 1
end
if !($x4 == $saved4)
printf "FAIL: post-return x4\n"
quit 1
end
if !($x5 == $saved5)
printf "FAIL: post-return x5\n"
quit 1
end
if !($x6 == $saved6)
printf "FAIL: post-return x6\n"
quit 1
end
if !($x7 == $saved7)
printf "FAIL: post-return x7\n"
quit 1
end
if !($x8 == $saved8)
printf "FAIL: post-return x8\n"
quit 1
end
if !($x9 == $saved9)
printf "FAIL: post-return x9\n"
quit 1
end
if !($x10 == $saved10)
printf "FAIL: post-return x10\n"
quit 1
end
if !($x11 == $saved11)
printf "FAIL: post-return x11\n"
quit 1
end
if !($x12 == $saved12)
printf "FAIL: post-return x12\n"
quit 1
end
if !($x13 == $saved13)
printf "FAIL: post-return x13\n"
quit 1
end
if !($x14 == $saved14)
printf "FAIL: post-return x14\n"
quit 1
end
if !($x15 == $saved15)
printf "FAIL: post-return x15\n"
quit 1
end
if !($x16 == $saved16)
printf "FAIL: post-return x16\n"
quit 1
end
if !($x17 == $saved17)
printf "FAIL: post-return x17\n"
quit 1
end
if !($x18 == $saved18)
printf "FAIL: post-return x18\n"
quit 1
end
if !($x19 == $saved19)
printf "FAIL: post-return x19\n"
quit 1
end
if !($x20 == $saved20)
printf "FAIL: post-return x20\n"
quit 1
end
if !($x21 == $saved21)
printf "FAIL: post-return x21\n"
quit 1
end
if !($x22 == $saved22)
printf "FAIL: post-return x22\n"
quit 1
end
if !($x23 == $saved23)
printf "FAIL: post-return x23\n"
quit 1
end
if !($x24 == $saved24)
printf "FAIL: post-return x24\n"
quit 1
end
if !($x25 == $saved25)
printf "FAIL: post-return x25\n"
quit 1
end
if !($x26 == $saved26)
printf "FAIL: post-return x26\n"
quit 1
end
if !($x27 == $saved27)
printf "FAIL: post-return x27\n"
quit 1
end
if !($x28 == $saved28)
printf "FAIL: post-return x28\n"
quit 1
end
if !($x29 == $saved29)
printf "FAIL: post-return x29\n"
quit 1
end
if !($x30 == $saved30)
printf "FAIL: post-return x30\n"
quit 1
end
if !($x31 == $saved31)
printf "FAIL: post-return x31\n"
quit 1
end
if !($pc == $before_pc + $length)
printf "FAIL: post-return PC\n"
quit 1
end
if !(($sstatus & 2) == ($before_status & 2))
printf "FAIL: post-return SIE\n"
quit 1
end
printf "POST_SRET status=%#lx (SPP=%d SPIE=%d)\n", $sstatus, ($sstatus >> 8) & 1, ($sstatus >> 5) & 1
if !((($sstatus >> 5) & 1) == 0 && ($sstatus & 0x100) == 0)
printf "FAIL: sret SPP and version-specific SPIE\n"
quit 1
end
set $completed = $completed + 1
printf "AFTER PASS: all 32 GPR slots, sp, PC, SIE; count=%d status=%#lx\n", $completed, $sstatus
continue
end
break *trap
commands
silent
set $entry_status = $sstatus
if !($sepc == $before_pc && $scause == 3)
printf "FAIL: entry sepc/cause\n"
quit 1
end
if !(($sstatus & 2) == 0 && ($sstatus & 0x100) != 0)
printf "FAIL: entry SIE/SPP\n"
quit 1
end
if !((($sstatus >> 5) & 1) == (($before_status >> 1) & 1))
printf "FAIL: entry SPIE\n"
quit 1
end
set $entered = $entered + 1
if !($a0 == $sp && $sp == $saved2 - 288 && ((unsigned long)$sp & 15) == 0)
printf "FAIL: C ABI frame pointer and alignment\n"
quit 1
end
if !(*(unsigned long *)($a0 + 0) == $saved0)
printf "FAIL: frame x0\n"
quit 1
end
if !(*(unsigned long *)($a0 + 8) == $saved1)
printf "FAIL: frame x1\n"
quit 1
end
if !(*(unsigned long *)($a0 + 16) == $saved2)
printf "FAIL: frame x2\n"
quit 1
end
if !(*(unsigned long *)($a0 + 24) == $saved3)
printf "FAIL: frame x3\n"
quit 1
end
if !(*(unsigned long *)($a0 + 32) == $saved4)
printf "FAIL: frame x4\n"
quit 1
end
if !(*(unsigned long *)($a0 + 40) == $saved5)
printf "FAIL: frame x5\n"
quit 1
end
if !(*(unsigned long *)($a0 + 48) == $saved6)
printf "FAIL: frame x6\n"
quit 1
end
if !(*(unsigned long *)($a0 + 56) == $saved7)
printf "FAIL: frame x7\n"
quit 1
end
if !(*(unsigned long *)($a0 + 64) == $saved8)
printf "FAIL: frame x8\n"
quit 1
end
if !(*(unsigned long *)($a0 + 72) == $saved9)
printf "FAIL: frame x9\n"
quit 1
end
if !(*(unsigned long *)($a0 + 80) == $saved10)
printf "FAIL: frame x10\n"
quit 1
end
if !(*(unsigned long *)($a0 + 88) == $saved11)
printf "FAIL: frame x11\n"
quit 1
end
if !(*(unsigned long *)($a0 + 96) == $saved12)
printf "FAIL: frame x12\n"
quit 1
end
if !(*(unsigned long *)($a0 + 104) == $saved13)
printf "FAIL: frame x13\n"
quit 1
end
if !(*(unsigned long *)($a0 + 112) == $saved14)
printf "FAIL: frame x14\n"
quit 1
end
if !(*(unsigned long *)($a0 + 120) == $saved15)
printf "FAIL: frame x15\n"
quit 1
end
if !(*(unsigned long *)($a0 + 128) == $saved16)
printf "FAIL: frame x16\n"
quit 1
end
if !(*(unsigned long *)($a0 + 136) == $saved17)
printf "FAIL: frame x17\n"
quit 1
end
if !(*(unsigned long *)($a0 + 144) == $saved18)
printf "FAIL: frame x18\n"
quit 1
end
if !(*(unsigned long *)($a0 + 152) == $saved19)
printf "FAIL: frame x19\n"
quit 1
end
if !(*(unsigned long *)($a0 + 160) == $saved20)
printf "FAIL: frame x20\n"
quit 1
end
if !(*(unsigned long *)($a0 + 168) == $saved21)
printf "FAIL: frame x21\n"
quit 1
end
if !(*(unsigned long *)($a0 + 176) == $saved22)
printf "FAIL: frame x22\n"
quit 1
end
if !(*(unsigned long *)($a0 + 184) == $saved23)
printf "FAIL: frame x23\n"
quit 1
end
if !(*(unsigned long *)($a0 + 192) == $saved24)
printf "FAIL: frame x24\n"
quit 1
end
if !(*(unsigned long *)($a0 + 200) == $saved25)
printf "FAIL: frame x25\n"
quit 1
end
if !(*(unsigned long *)($a0 + 208) == $saved26)
printf "FAIL: frame x26\n"
quit 1
end
if !(*(unsigned long *)($a0 + 216) == $saved27)
printf "FAIL: frame x27\n"
quit 1
end
if !(*(unsigned long *)($a0 + 224) == $saved28)
printf "FAIL: frame x28\n"
quit 1
end
if !(*(unsigned long *)($a0 + 232) == $saved29)
printf "FAIL: frame x29\n"
quit 1
end
if !(*(unsigned long *)($a0 + 240) == $saved30)
printf "FAIL: frame x30\n"
quit 1
end
if !(*(unsigned long *)($a0 + 248) == $saved31)
printf "FAIL: frame x31\n"
quit 1
end
if !(*(unsigned long *)($a0+256) == $entry_status)
printf "FAIL: saved status\n"
quit 1
end
if !(*(unsigned long *)($a0+264) == $before_pc)
printf "FAIL: saved epc\n"
quit 1
end
if !(*(unsigned long *)($a0+272) == $stval)
printf "FAIL: saved stval\n"
quit 1
end
if !(*(unsigned long *)($a0+280) == $scause)
printf "FAIL: saved scause\n"
quit 1
end
set $called = $called + 1
printf "TRAP ABI PASS: a0=%#lx frame_size=288\n", $a0
continue
end
break *0xffffffffc0200cba
commands
silent
if !($x0 == $saved0)
printf "FAIL: before sret x0\n"
quit 1
end
if !($x1 == $saved1)
printf "FAIL: before sret x1\n"
quit 1
end
if !($x2 == $saved2)
printf "FAIL: before sret x2\n"
quit 1
end
if !($x3 == $saved3)
printf "FAIL: before sret x3\n"
quit 1
end
if !($x4 == $saved4)
printf "FAIL: before sret x4\n"
quit 1
end
if !($x5 == $saved5)
printf "FAIL: before sret x5\n"
quit 1
end
if !($x6 == $saved6)
printf "FAIL: before sret x6\n"
quit 1
end
if !($x7 == $saved7)
printf "FAIL: before sret x7\n"
quit 1
end
if !($x8 == $saved8)
printf "FAIL: before sret x8\n"
quit 1
end
if !($x9 == $saved9)
printf "FAIL: before sret x9\n"
quit 1
end
if !($x10 == $saved10)
printf "FAIL: before sret x10\n"
quit 1
end
if !($x11 == $saved11)
printf "FAIL: before sret x11\n"
quit 1
end
if !($x12 == $saved12)
printf "FAIL: before sret x12\n"
quit 1
end
if !($x13 == $saved13)
printf "FAIL: before sret x13\n"
quit 1
end
if !($x14 == $saved14)
printf "FAIL: before sret x14\n"
quit 1
end
if !($x15 == $saved15)
printf "FAIL: before sret x15\n"
quit 1
end
if !($x16 == $saved16)
printf "FAIL: before sret x16\n"
quit 1
end
if !($x17 == $saved17)
printf "FAIL: before sret x17\n"
quit 1
end
if !($x18 == $saved18)
printf "FAIL: before sret x18\n"
quit 1
end
if !($x19 == $saved19)
printf "FAIL: before sret x19\n"
quit 1
end
if !($x20 == $saved20)
printf "FAIL: before sret x20\n"
quit 1
end
if !($x21 == $saved21)
printf "FAIL: before sret x21\n"
quit 1
end
if !($x22 == $saved22)
printf "FAIL: before sret x22\n"
quit 1
end
if !($x23 == $saved23)
printf "FAIL: before sret x23\n"
quit 1
end
if !($x24 == $saved24)
printf "FAIL: before sret x24\n"
quit 1
end
if !($x25 == $saved25)
printf "FAIL: before sret x25\n"
quit 1
end
if !($x26 == $saved26)
printf "FAIL: before sret x26\n"
quit 1
end
if !($x27 == $saved27)
printf "FAIL: before sret x27\n"
quit 1
end
if !($x28 == $saved28)
printf "FAIL: before sret x28\n"
quit 1
end
if !($x29 == $saved29)
printf "FAIL: before sret x29\n"
quit 1
end
if !($x30 == $saved30)
printf "FAIL: before sret x30\n"
quit 1
end
if !($x31 == $saved31)
printf "FAIL: before sret x31\n"
quit 1
end
if !($sepc == $before_pc + $length)
printf "FAIL: restored sepc\n"
quit 1
end
if !($sstatus == $entry_status)
printf "FAIL: restored sstatus\n"
quit 1
end
set $restored = $restored + 1
printf "RESTORE PASS: sp=%#lx sepc=%#lx status=%#lx\n", $sp, $sepc, $sstatus
continue
end
break *sbi_shutdown
commands
silent
if !($completed == 4 && $entered == 4 && $called == 4 && $restored == 4)
printf "FAIL: four complete trap lifecycles\n"
quit 1
end
printf "MEMBER_A_GDB_PASS: 4 lifecycles, 16/32-bit breakpoints, SIE=0/1\n"
detach
quit 0
end
target remote 127.0.0.1:46977
continue
