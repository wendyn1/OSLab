
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00006297          	auipc	t0,0x6
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0206000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00006297          	auipc	t0,0x6
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0206008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02052b7          	lui	t0,0xc0205
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0205137          	lui	sp,0xc0205

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 1. 使用临时寄存器 t1 计算栈顶的精确地址
    lui t1, %hi(bootstacktop)
ffffffffc0200040:	c0205337          	lui	t1,0xc0205
    addi t1, t1, %lo(bootstacktop)
ffffffffc0200044:	00030313          	mv	t1,t1
    # 2. 将精确地址一次性地、安全地传给 sp
    mv sp, t1
ffffffffc0200048:	811a                	mv	sp,t1
    # 现在栈指针已经完美设置，可以安全地调用任何C函数了
    # 然后跳转到 kern_init (不再返回)
    lui t0, %hi(kern_init)
ffffffffc020004a:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc020004e:	05428293          	addi	t0,t0,84 # ffffffffc0200054 <kern_init>
    jr t0
ffffffffc0200052:	8282                	jr	t0

ffffffffc0200054 <kern_init>:
int kern_init(void) __attribute__((noreturn));
void grade_backtrace(void);

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc0200054:	00006517          	auipc	a0,0x6
ffffffffc0200058:	fd450513          	addi	a0,a0,-44 # ffffffffc0206028 <free_area>
ffffffffc020005c:	00006617          	auipc	a2,0x6
ffffffffc0200060:	44460613          	addi	a2,a2,1092 # ffffffffc02064a0 <end>
int kern_init(void) {
ffffffffc0200064:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc0200066:	8e09                	sub	a2,a2,a0
ffffffffc0200068:	4581                	li	a1,0
int kern_init(void) {
ffffffffc020006a:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc020006c:	659010ef          	jal	ra,ffffffffc0201ec4 <memset>
    dtb_init();
ffffffffc0200070:	40e000ef          	jal	ra,ffffffffc020047e <dtb_init>
    cons_init();  // init the console
ffffffffc0200074:	3fc000ef          	jal	ra,ffffffffc0200470 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200078:	00002517          	auipc	a0,0x2
ffffffffc020007c:	e6050513          	addi	a0,a0,-416 # ffffffffc0201ed8 <etext+0x2>
ffffffffc0200080:	090000ef          	jal	ra,ffffffffc0200110 <cputs>

    print_kerninfo();
ffffffffc0200084:	0dc000ef          	jal	ra,ffffffffc0200160 <print_kerninfo>

    // grade_backtrace();
    idt_init();  // init interrupt descriptor table
ffffffffc0200088:	7b2000ef          	jal	ra,ffffffffc020083a <idt_init>

    pmm_init();  // init physical memory management
ffffffffc020008c:	6b4010ef          	jal	ra,ffffffffc0201740 <pmm_init>

    idt_init();  // init interrupt descriptor table
ffffffffc0200090:	7aa000ef          	jal	ra,ffffffffc020083a <idt_init>

    clock_init();   // init clock interrupt
ffffffffc0200094:	39a000ef          	jal	ra,ffffffffc020042e <clock_init>
    intr_enable();  // enable irq interrupt
ffffffffc0200098:	796000ef          	jal	ra,ffffffffc020082e <intr_enable>

    /* do nothing */
    while (1)
ffffffffc020009c:	a001                	j	ffffffffc020009c <kern_init+0x48>

ffffffffc020009e <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc020009e:	1141                	addi	sp,sp,-16
ffffffffc02000a0:	e022                	sd	s0,0(sp)
ffffffffc02000a2:	e406                	sd	ra,8(sp)
ffffffffc02000a4:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc02000a6:	3cc000ef          	jal	ra,ffffffffc0200472 <cons_putc>
    (*cnt) ++;
ffffffffc02000aa:	401c                	lw	a5,0(s0)
}
ffffffffc02000ac:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc02000ae:	2785                	addiw	a5,a5,1
ffffffffc02000b0:	c01c                	sw	a5,0(s0)
}
ffffffffc02000b2:	6402                	ld	s0,0(sp)
ffffffffc02000b4:	0141                	addi	sp,sp,16
ffffffffc02000b6:	8082                	ret

ffffffffc02000b8 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000b8:	1101                	addi	sp,sp,-32
ffffffffc02000ba:	862a                	mv	a2,a0
ffffffffc02000bc:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000be:	00000517          	auipc	a0,0x0
ffffffffc02000c2:	fe050513          	addi	a0,a0,-32 # ffffffffc020009e <cputch>
ffffffffc02000c6:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000c8:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc02000ca:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000cc:	0c9010ef          	jal	ra,ffffffffc0201994 <vprintfmt>
    return cnt;
}
ffffffffc02000d0:	60e2                	ld	ra,24(sp)
ffffffffc02000d2:	4532                	lw	a0,12(sp)
ffffffffc02000d4:	6105                	addi	sp,sp,32
ffffffffc02000d6:	8082                	ret

ffffffffc02000d8 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc02000d8:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc02000da:	02810313          	addi	t1,sp,40 # ffffffffc0205028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc02000de:	8e2a                	mv	t3,a0
ffffffffc02000e0:	f42e                	sd	a1,40(sp)
ffffffffc02000e2:	f832                	sd	a2,48(sp)
ffffffffc02000e4:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000e6:	00000517          	auipc	a0,0x0
ffffffffc02000ea:	fb850513          	addi	a0,a0,-72 # ffffffffc020009e <cputch>
ffffffffc02000ee:	004c                	addi	a1,sp,4
ffffffffc02000f0:	869a                	mv	a3,t1
ffffffffc02000f2:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc02000f4:	ec06                	sd	ra,24(sp)
ffffffffc02000f6:	e0ba                	sd	a4,64(sp)
ffffffffc02000f8:	e4be                	sd	a5,72(sp)
ffffffffc02000fa:	e8c2                	sd	a6,80(sp)
ffffffffc02000fc:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc02000fe:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200100:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200102:	093010ef          	jal	ra,ffffffffc0201994 <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc0200106:	60e2                	ld	ra,24(sp)
ffffffffc0200108:	4512                	lw	a0,4(sp)
ffffffffc020010a:	6125                	addi	sp,sp,96
ffffffffc020010c:	8082                	ret

ffffffffc020010e <cputchar>:

/* cputchar - writes a single character to stdout */
void
cputchar(int c) {
    cons_putc(c);
ffffffffc020010e:	a695                	j	ffffffffc0200472 <cons_putc>

ffffffffc0200110 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200110:	1101                	addi	sp,sp,-32
ffffffffc0200112:	e822                	sd	s0,16(sp)
ffffffffc0200114:	ec06                	sd	ra,24(sp)
ffffffffc0200116:	e426                	sd	s1,8(sp)
ffffffffc0200118:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020011a:	00054503          	lbu	a0,0(a0)
ffffffffc020011e:	c51d                	beqz	a0,ffffffffc020014c <cputs+0x3c>
ffffffffc0200120:	0405                	addi	s0,s0,1
ffffffffc0200122:	4485                	li	s1,1
ffffffffc0200124:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200126:	34c000ef          	jal	ra,ffffffffc0200472 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020012a:	00044503          	lbu	a0,0(s0)
ffffffffc020012e:	008487bb          	addw	a5,s1,s0
ffffffffc0200132:	0405                	addi	s0,s0,1
ffffffffc0200134:	f96d                	bnez	a0,ffffffffc0200126 <cputs+0x16>
    (*cnt) ++;
ffffffffc0200136:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc020013a:	4529                	li	a0,10
ffffffffc020013c:	336000ef          	jal	ra,ffffffffc0200472 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc0200140:	60e2                	ld	ra,24(sp)
ffffffffc0200142:	8522                	mv	a0,s0
ffffffffc0200144:	6442                	ld	s0,16(sp)
ffffffffc0200146:	64a2                	ld	s1,8(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc020014c:	4405                	li	s0,1
ffffffffc020014e:	b7f5                	j	ffffffffc020013a <cputs+0x2a>

ffffffffc0200150 <getchar>:

/* getchar - reads a single non-zero character from stdin */
int
getchar(void) {
ffffffffc0200150:	1141                	addi	sp,sp,-16
ffffffffc0200152:	e406                	sd	ra,8(sp)
    int c;
    while ((c = cons_getc()) == 0)
ffffffffc0200154:	326000ef          	jal	ra,ffffffffc020047a <cons_getc>
ffffffffc0200158:	dd75                	beqz	a0,ffffffffc0200154 <getchar+0x4>
        /* do nothing */;
    return c;
}
ffffffffc020015a:	60a2                	ld	ra,8(sp)
ffffffffc020015c:	0141                	addi	sp,sp,16
ffffffffc020015e:	8082                	ret

ffffffffc0200160 <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc0200160:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
ffffffffc0200162:	00002517          	auipc	a0,0x2
ffffffffc0200166:	d9650513          	addi	a0,a0,-618 # ffffffffc0201ef8 <etext+0x22>
void print_kerninfo(void) {
ffffffffc020016a:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020016c:	f6dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", kern_init);
ffffffffc0200170:	00000597          	auipc	a1,0x0
ffffffffc0200174:	ee458593          	addi	a1,a1,-284 # ffffffffc0200054 <kern_init>
ffffffffc0200178:	00002517          	auipc	a0,0x2
ffffffffc020017c:	da050513          	addi	a0,a0,-608 # ffffffffc0201f18 <etext+0x42>
ffffffffc0200180:	f59ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc0200184:	00002597          	auipc	a1,0x2
ffffffffc0200188:	d5258593          	addi	a1,a1,-686 # ffffffffc0201ed6 <etext>
ffffffffc020018c:	00002517          	auipc	a0,0x2
ffffffffc0200190:	dac50513          	addi	a0,a0,-596 # ffffffffc0201f38 <etext+0x62>
ffffffffc0200194:	f45ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200198:	00006597          	auipc	a1,0x6
ffffffffc020019c:	e9058593          	addi	a1,a1,-368 # ffffffffc0206028 <free_area>
ffffffffc02001a0:	00002517          	auipc	a0,0x2
ffffffffc02001a4:	db850513          	addi	a0,a0,-584 # ffffffffc0201f58 <etext+0x82>
ffffffffc02001a8:	f31ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc02001ac:	00006597          	auipc	a1,0x6
ffffffffc02001b0:	2f458593          	addi	a1,a1,756 # ffffffffc02064a0 <end>
ffffffffc02001b4:	00002517          	auipc	a0,0x2
ffffffffc02001b8:	dc450513          	addi	a0,a0,-572 # ffffffffc0201f78 <etext+0xa2>
ffffffffc02001bc:	f1dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - kern_init + 1023) / 1024);
ffffffffc02001c0:	00006597          	auipc	a1,0x6
ffffffffc02001c4:	6df58593          	addi	a1,a1,1759 # ffffffffc020689f <end+0x3ff>
ffffffffc02001c8:	00000797          	auipc	a5,0x0
ffffffffc02001cc:	e8c78793          	addi	a5,a5,-372 # ffffffffc0200054 <kern_init>
ffffffffc02001d0:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001d4:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02001d8:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001da:	3ff5f593          	andi	a1,a1,1023
ffffffffc02001de:	95be                	add	a1,a1,a5
ffffffffc02001e0:	85a9                	srai	a1,a1,0xa
ffffffffc02001e2:	00002517          	auipc	a0,0x2
ffffffffc02001e6:	db650513          	addi	a0,a0,-586 # ffffffffc0201f98 <etext+0xc2>
}
ffffffffc02001ea:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001ec:	b5f5                	j	ffffffffc02000d8 <cprintf>

ffffffffc02001ee <print_stackframe>:
 * Note that, the length of ebp-chain is limited. In boot/bootasm.S, before
 * jumping
 * to the kernel entry, the value of ebp has been set to zero, that's the
 * boundary.
 * */
void print_stackframe(void) {
ffffffffc02001ee:	1141                	addi	sp,sp,-16
    
    panic("Not Implemented!");
ffffffffc02001f0:	00002617          	auipc	a2,0x2
ffffffffc02001f4:	dd860613          	addi	a2,a2,-552 # ffffffffc0201fc8 <etext+0xf2>
ffffffffc02001f8:	04e00593          	li	a1,78
ffffffffc02001fc:	00002517          	auipc	a0,0x2
ffffffffc0200200:	de450513          	addi	a0,a0,-540 # ffffffffc0201fe0 <etext+0x10a>
void print_stackframe(void) {
ffffffffc0200204:	e406                	sd	ra,8(sp)
    panic("Not Implemented!");
ffffffffc0200206:	1cc000ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc020020a <mon_help>:
    }
}

/* mon_help - print the information about mon_* functions */
int
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc020020a:	1141                	addi	sp,sp,-16
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc020020c:	00002617          	auipc	a2,0x2
ffffffffc0200210:	dec60613          	addi	a2,a2,-532 # ffffffffc0201ff8 <etext+0x122>
ffffffffc0200214:	00002597          	auipc	a1,0x2
ffffffffc0200218:	e0458593          	addi	a1,a1,-508 # ffffffffc0202018 <etext+0x142>
ffffffffc020021c:	00002517          	auipc	a0,0x2
ffffffffc0200220:	e0450513          	addi	a0,a0,-508 # ffffffffc0202020 <etext+0x14a>
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200224:	e406                	sd	ra,8(sp)
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc0200226:	eb3ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc020022a:	00002617          	auipc	a2,0x2
ffffffffc020022e:	e0660613          	addi	a2,a2,-506 # ffffffffc0202030 <etext+0x15a>
ffffffffc0200232:	00002597          	auipc	a1,0x2
ffffffffc0200236:	e2658593          	addi	a1,a1,-474 # ffffffffc0202058 <etext+0x182>
ffffffffc020023a:	00002517          	auipc	a0,0x2
ffffffffc020023e:	de650513          	addi	a0,a0,-538 # ffffffffc0202020 <etext+0x14a>
ffffffffc0200242:	e97ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc0200246:	00002617          	auipc	a2,0x2
ffffffffc020024a:	e2260613          	addi	a2,a2,-478 # ffffffffc0202068 <etext+0x192>
ffffffffc020024e:	00002597          	auipc	a1,0x2
ffffffffc0200252:	e3a58593          	addi	a1,a1,-454 # ffffffffc0202088 <etext+0x1b2>
ffffffffc0200256:	00002517          	auipc	a0,0x2
ffffffffc020025a:	dca50513          	addi	a0,a0,-566 # ffffffffc0202020 <etext+0x14a>
ffffffffc020025e:	e7bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    }
    return 0;
}
ffffffffc0200262:	60a2                	ld	ra,8(sp)
ffffffffc0200264:	4501                	li	a0,0
ffffffffc0200266:	0141                	addi	sp,sp,16
ffffffffc0200268:	8082                	ret

ffffffffc020026a <mon_kerninfo>:
/* *
 * mon_kerninfo - call print_kerninfo in kern/debug/kdebug.c to
 * print the memory occupancy in kernel.
 * */
int
mon_kerninfo(int argc, char **argv, struct trapframe *tf) {
ffffffffc020026a:	1141                	addi	sp,sp,-16
ffffffffc020026c:	e406                	sd	ra,8(sp)
    print_kerninfo();
ffffffffc020026e:	ef3ff0ef          	jal	ra,ffffffffc0200160 <print_kerninfo>
    return 0;
}
ffffffffc0200272:	60a2                	ld	ra,8(sp)
ffffffffc0200274:	4501                	li	a0,0
ffffffffc0200276:	0141                	addi	sp,sp,16
ffffffffc0200278:	8082                	ret

ffffffffc020027a <mon_backtrace>:
/* *
 * mon_backtrace - call print_stackframe in kern/debug/kdebug.c to
 * print a backtrace of the stack.
 * */
int
mon_backtrace(int argc, char **argv, struct trapframe *tf) {
ffffffffc020027a:	1141                	addi	sp,sp,-16
ffffffffc020027c:	e406                	sd	ra,8(sp)
    print_stackframe();
ffffffffc020027e:	f71ff0ef          	jal	ra,ffffffffc02001ee <print_stackframe>
    return 0;
}
ffffffffc0200282:	60a2                	ld	ra,8(sp)
ffffffffc0200284:	4501                	li	a0,0
ffffffffc0200286:	0141                	addi	sp,sp,16
ffffffffc0200288:	8082                	ret

ffffffffc020028a <kmonitor>:
kmonitor(struct trapframe *tf) {
ffffffffc020028a:	7115                	addi	sp,sp,-224
ffffffffc020028c:	ed5e                	sd	s7,152(sp)
ffffffffc020028e:	8baa                	mv	s7,a0
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc0200290:	00002517          	auipc	a0,0x2
ffffffffc0200294:	e0850513          	addi	a0,a0,-504 # ffffffffc0202098 <etext+0x1c2>
kmonitor(struct trapframe *tf) {
ffffffffc0200298:	ed86                	sd	ra,216(sp)
ffffffffc020029a:	e9a2                	sd	s0,208(sp)
ffffffffc020029c:	e5a6                	sd	s1,200(sp)
ffffffffc020029e:	e1ca                	sd	s2,192(sp)
ffffffffc02002a0:	fd4e                	sd	s3,184(sp)
ffffffffc02002a2:	f952                	sd	s4,176(sp)
ffffffffc02002a4:	f556                	sd	s5,168(sp)
ffffffffc02002a6:	f15a                	sd	s6,160(sp)
ffffffffc02002a8:	e962                	sd	s8,144(sp)
ffffffffc02002aa:	e566                	sd	s9,136(sp)
ffffffffc02002ac:	e16a                	sd	s10,128(sp)
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc02002ae:	e2bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
ffffffffc02002b2:	00002517          	auipc	a0,0x2
ffffffffc02002b6:	e0e50513          	addi	a0,a0,-498 # ffffffffc02020c0 <etext+0x1ea>
ffffffffc02002ba:	e1fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    if (tf != NULL) {
ffffffffc02002be:	000b8563          	beqz	s7,ffffffffc02002c8 <kmonitor+0x3e>
        print_trapframe(tf);
ffffffffc02002c2:	855e                	mv	a0,s7
ffffffffc02002c4:	756000ef          	jal	ra,ffffffffc0200a1a <print_trapframe>
ffffffffc02002c8:	00002c17          	auipc	s8,0x2
ffffffffc02002cc:	e68c0c13          	addi	s8,s8,-408 # ffffffffc0202130 <commands>
        if ((buf = readline("K> ")) != NULL) {
ffffffffc02002d0:	00002917          	auipc	s2,0x2
ffffffffc02002d4:	e1890913          	addi	s2,s2,-488 # ffffffffc02020e8 <etext+0x212>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02002d8:	00002497          	auipc	s1,0x2
ffffffffc02002dc:	e1848493          	addi	s1,s1,-488 # ffffffffc02020f0 <etext+0x21a>
        if (argc == MAXARGS - 1) {
ffffffffc02002e0:	49bd                	li	s3,15
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc02002e2:	00002b17          	auipc	s6,0x2
ffffffffc02002e6:	e16b0b13          	addi	s6,s6,-490 # ffffffffc02020f8 <etext+0x222>
        argv[argc ++] = buf;
ffffffffc02002ea:	00002a17          	auipc	s4,0x2
ffffffffc02002ee:	d2ea0a13          	addi	s4,s4,-722 # ffffffffc0202018 <etext+0x142>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc02002f2:	4a8d                	li	s5,3
        if ((buf = readline("K> ")) != NULL) {
ffffffffc02002f4:	854a                	mv	a0,s2
ffffffffc02002f6:	221010ef          	jal	ra,ffffffffc0201d16 <readline>
ffffffffc02002fa:	842a                	mv	s0,a0
ffffffffc02002fc:	dd65                	beqz	a0,ffffffffc02002f4 <kmonitor+0x6a>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02002fe:	00054583          	lbu	a1,0(a0)
    int argc = 0;
ffffffffc0200302:	4c81                	li	s9,0
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc0200304:	e1bd                	bnez	a1,ffffffffc020036a <kmonitor+0xe0>
    if (argc == 0) {
ffffffffc0200306:	fe0c87e3          	beqz	s9,ffffffffc02002f4 <kmonitor+0x6a>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020030a:	6582                	ld	a1,0(sp)
ffffffffc020030c:	00002d17          	auipc	s10,0x2
ffffffffc0200310:	e24d0d13          	addi	s10,s10,-476 # ffffffffc0202130 <commands>
        argv[argc ++] = buf;
ffffffffc0200314:	8552                	mv	a0,s4
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200316:	4401                	li	s0,0
ffffffffc0200318:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020031a:	351010ef          	jal	ra,ffffffffc0201e6a <strcmp>
ffffffffc020031e:	c919                	beqz	a0,ffffffffc0200334 <kmonitor+0xaa>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200320:	2405                	addiw	s0,s0,1
ffffffffc0200322:	0b540063          	beq	s0,s5,ffffffffc02003c2 <kmonitor+0x138>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc0200326:	000d3503          	ld	a0,0(s10)
ffffffffc020032a:	6582                	ld	a1,0(sp)
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc020032c:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020032e:	33d010ef          	jal	ra,ffffffffc0201e6a <strcmp>
ffffffffc0200332:	f57d                	bnez	a0,ffffffffc0200320 <kmonitor+0x96>
            return commands[i].func(argc - 1, argv + 1, tf);
ffffffffc0200334:	00141793          	slli	a5,s0,0x1
ffffffffc0200338:	97a2                	add	a5,a5,s0
ffffffffc020033a:	078e                	slli	a5,a5,0x3
ffffffffc020033c:	97e2                	add	a5,a5,s8
ffffffffc020033e:	6b9c                	ld	a5,16(a5)
ffffffffc0200340:	865e                	mv	a2,s7
ffffffffc0200342:	002c                	addi	a1,sp,8
ffffffffc0200344:	fffc851b          	addiw	a0,s9,-1
ffffffffc0200348:	9782                	jalr	a5
            if (runcmd(buf, tf) < 0) {
ffffffffc020034a:	fa0555e3          	bgez	a0,ffffffffc02002f4 <kmonitor+0x6a>
}
ffffffffc020034e:	60ee                	ld	ra,216(sp)
ffffffffc0200350:	644e                	ld	s0,208(sp)
ffffffffc0200352:	64ae                	ld	s1,200(sp)
ffffffffc0200354:	690e                	ld	s2,192(sp)
ffffffffc0200356:	79ea                	ld	s3,184(sp)
ffffffffc0200358:	7a4a                	ld	s4,176(sp)
ffffffffc020035a:	7aaa                	ld	s5,168(sp)
ffffffffc020035c:	7b0a                	ld	s6,160(sp)
ffffffffc020035e:	6bea                	ld	s7,152(sp)
ffffffffc0200360:	6c4a                	ld	s8,144(sp)
ffffffffc0200362:	6caa                	ld	s9,136(sp)
ffffffffc0200364:	6d0a                	ld	s10,128(sp)
ffffffffc0200366:	612d                	addi	sp,sp,224
ffffffffc0200368:	8082                	ret
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020036a:	8526                	mv	a0,s1
ffffffffc020036c:	343010ef          	jal	ra,ffffffffc0201eae <strchr>
ffffffffc0200370:	c901                	beqz	a0,ffffffffc0200380 <kmonitor+0xf6>
ffffffffc0200372:	00144583          	lbu	a1,1(s0)
            *buf ++ = '\0';
ffffffffc0200376:	00040023          	sb	zero,0(s0)
ffffffffc020037a:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020037c:	d5c9                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc020037e:	b7f5                	j	ffffffffc020036a <kmonitor+0xe0>
        if (*buf == '\0') {
ffffffffc0200380:	00044783          	lbu	a5,0(s0)
ffffffffc0200384:	d3c9                	beqz	a5,ffffffffc0200306 <kmonitor+0x7c>
        if (argc == MAXARGS - 1) {
ffffffffc0200386:	033c8963          	beq	s9,s3,ffffffffc02003b8 <kmonitor+0x12e>
        argv[argc ++] = buf;
ffffffffc020038a:	003c9793          	slli	a5,s9,0x3
ffffffffc020038e:	0118                	addi	a4,sp,128
ffffffffc0200390:	97ba                	add	a5,a5,a4
ffffffffc0200392:	f887b023          	sd	s0,-128(a5)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc0200396:	00044583          	lbu	a1,0(s0)
        argv[argc ++] = buf;
ffffffffc020039a:	2c85                	addiw	s9,s9,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc020039c:	e591                	bnez	a1,ffffffffc02003a8 <kmonitor+0x11e>
ffffffffc020039e:	b7b5                	j	ffffffffc020030a <kmonitor+0x80>
ffffffffc02003a0:	00144583          	lbu	a1,1(s0)
            buf ++;
ffffffffc02003a4:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc02003a6:	d1a5                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc02003a8:	8526                	mv	a0,s1
ffffffffc02003aa:	305010ef          	jal	ra,ffffffffc0201eae <strchr>
ffffffffc02003ae:	d96d                	beqz	a0,ffffffffc02003a0 <kmonitor+0x116>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02003b0:	00044583          	lbu	a1,0(s0)
ffffffffc02003b4:	d9a9                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc02003b6:	bf55                	j	ffffffffc020036a <kmonitor+0xe0>
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc02003b8:	45c1                	li	a1,16
ffffffffc02003ba:	855a                	mv	a0,s6
ffffffffc02003bc:	d1dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc02003c0:	b7e9                	j	ffffffffc020038a <kmonitor+0x100>
    cprintf("Unknown command '%s'\n", argv[0]);
ffffffffc02003c2:	6582                	ld	a1,0(sp)
ffffffffc02003c4:	00002517          	auipc	a0,0x2
ffffffffc02003c8:	d5450513          	addi	a0,a0,-684 # ffffffffc0202118 <etext+0x242>
ffffffffc02003cc:	d0dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    return 0;
ffffffffc02003d0:	b715                	j	ffffffffc02002f4 <kmonitor+0x6a>

ffffffffc02003d2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02003d2:	00006317          	auipc	t1,0x6
ffffffffc02003d6:	06e30313          	addi	t1,t1,110 # ffffffffc0206440 <is_panic>
ffffffffc02003da:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02003de:	715d                	addi	sp,sp,-80
ffffffffc02003e0:	ec06                	sd	ra,24(sp)
ffffffffc02003e2:	e822                	sd	s0,16(sp)
ffffffffc02003e4:	f436                	sd	a3,40(sp)
ffffffffc02003e6:	f83a                	sd	a4,48(sp)
ffffffffc02003e8:	fc3e                	sd	a5,56(sp)
ffffffffc02003ea:	e0c2                	sd	a6,64(sp)
ffffffffc02003ec:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02003ee:	020e1a63          	bnez	t3,ffffffffc0200422 <__panic+0x50>
        goto panic_dead;
    }
    is_panic = 1;
ffffffffc02003f2:	4785                	li	a5,1
ffffffffc02003f4:	00f32023          	sw	a5,0(t1)

    // print the 'message'
    va_list ap;
    va_start(ap, fmt);
ffffffffc02003f8:	8432                	mv	s0,a2
ffffffffc02003fa:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02003fc:	862e                	mv	a2,a1
ffffffffc02003fe:	85aa                	mv	a1,a0
ffffffffc0200400:	00002517          	auipc	a0,0x2
ffffffffc0200404:	d7850513          	addi	a0,a0,-648 # ffffffffc0202178 <commands+0x48>
    va_start(ap, fmt);
ffffffffc0200408:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc020040a:	ccfff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    vcprintf(fmt, ap);
ffffffffc020040e:	65a2                	ld	a1,8(sp)
ffffffffc0200410:	8522                	mv	a0,s0
ffffffffc0200412:	ca7ff0ef          	jal	ra,ffffffffc02000b8 <vcprintf>
    cprintf("\n");
ffffffffc0200416:	00002517          	auipc	a0,0x2
ffffffffc020041a:	baa50513          	addi	a0,a0,-1110 # ffffffffc0201fc0 <etext+0xea>
ffffffffc020041e:	cbbff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    va_end(ap);

panic_dead:
    intr_disable();
ffffffffc0200422:	412000ef          	jal	ra,ffffffffc0200834 <intr_disable>
    while (1) {
        kmonitor(NULL);
ffffffffc0200426:	4501                	li	a0,0
ffffffffc0200428:	e63ff0ef          	jal	ra,ffffffffc020028a <kmonitor>
    while (1) {
ffffffffc020042c:	bfed                	j	ffffffffc0200426 <__panic+0x54>

ffffffffc020042e <clock_init>:

/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void clock_init(void) {
ffffffffc020042e:	1141                	addi	sp,sp,-16
ffffffffc0200430:	e406                	sd	ra,8(sp)
    // enable timer interrupt in sie
    set_csr(sie, MIP_STIP);
ffffffffc0200432:	02000793          	li	a5,32
ffffffffc0200436:	1047a7f3          	csrrs	a5,sie,a5
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc020043a:	c0102573          	rdtime	a0
    ticks = 0;

    cprintf("++ setup timer interrupts\n");
}

void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc020043e:	67e1                	lui	a5,0x18
ffffffffc0200440:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc0200444:	953e                	add	a0,a0,a5
ffffffffc0200446:	19f010ef          	jal	ra,ffffffffc0201de4 <sbi_set_timer>
}
ffffffffc020044a:	60a2                	ld	ra,8(sp)
    ticks = 0;
ffffffffc020044c:	00006797          	auipc	a5,0x6
ffffffffc0200450:	fe07be23          	sd	zero,-4(a5) # ffffffffc0206448 <ticks>
    cprintf("++ setup timer interrupts\n");
ffffffffc0200454:	00002517          	auipc	a0,0x2
ffffffffc0200458:	d4450513          	addi	a0,a0,-700 # ffffffffc0202198 <commands+0x68>
}
ffffffffc020045c:	0141                	addi	sp,sp,16
    cprintf("++ setup timer interrupts\n");
ffffffffc020045e:	b9ad                	j	ffffffffc02000d8 <cprintf>

ffffffffc0200460 <clock_set_next_event>:
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc0200460:	c0102573          	rdtime	a0
void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc0200464:	67e1                	lui	a5,0x18
ffffffffc0200466:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc020046a:	953e                	add	a0,a0,a5
ffffffffc020046c:	1790106f          	j	ffffffffc0201de4 <sbi_set_timer>

ffffffffc0200470 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200470:	8082                	ret

ffffffffc0200472 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200472:	0ff57513          	zext.b	a0,a0
ffffffffc0200476:	1550106f          	j	ffffffffc0201dca <sbi_console_putchar>

ffffffffc020047a <cons_getc>:
 * cons_getc - return the next input character from console,
 * or 0 if none waiting.
 * */
int cons_getc(void) {
    int c = 0;
    c = sbi_console_getchar();
ffffffffc020047a:	1850106f          	j	ffffffffc0201dfe <sbi_console_getchar>

ffffffffc020047e <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc020047e:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200480:	00002517          	auipc	a0,0x2
ffffffffc0200484:	d3850513          	addi	a0,a0,-712 # ffffffffc02021b8 <commands+0x88>
void dtb_init(void) {
ffffffffc0200488:	fc86                	sd	ra,120(sp)
ffffffffc020048a:	f8a2                	sd	s0,112(sp)
ffffffffc020048c:	e8d2                	sd	s4,80(sp)
ffffffffc020048e:	f4a6                	sd	s1,104(sp)
ffffffffc0200490:	f0ca                	sd	s2,96(sp)
ffffffffc0200492:	ecce                	sd	s3,88(sp)
ffffffffc0200494:	e4d6                	sd	s5,72(sp)
ffffffffc0200496:	e0da                	sd	s6,64(sp)
ffffffffc0200498:	fc5e                	sd	s7,56(sp)
ffffffffc020049a:	f862                	sd	s8,48(sp)
ffffffffc020049c:	f466                	sd	s9,40(sp)
ffffffffc020049e:	f06a                	sd	s10,32(sp)
ffffffffc02004a0:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc02004a2:	c37ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc02004a6:	00006597          	auipc	a1,0x6
ffffffffc02004aa:	b5a5b583          	ld	a1,-1190(a1) # ffffffffc0206000 <boot_hartid>
ffffffffc02004ae:	00002517          	auipc	a0,0x2
ffffffffc02004b2:	d1a50513          	addi	a0,a0,-742 # ffffffffc02021c8 <commands+0x98>
ffffffffc02004b6:	c23ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc02004ba:	00006417          	auipc	s0,0x6
ffffffffc02004be:	b4e40413          	addi	s0,s0,-1202 # ffffffffc0206008 <boot_dtb>
ffffffffc02004c2:	600c                	ld	a1,0(s0)
ffffffffc02004c4:	00002517          	auipc	a0,0x2
ffffffffc02004c8:	d1450513          	addi	a0,a0,-748 # ffffffffc02021d8 <commands+0xa8>
ffffffffc02004cc:	c0dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc02004d0:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc02004d4:	00002517          	auipc	a0,0x2
ffffffffc02004d8:	d1c50513          	addi	a0,a0,-740 # ffffffffc02021f0 <commands+0xc0>
    if (boot_dtb == 0) {
ffffffffc02004dc:	120a0463          	beqz	s4,ffffffffc0200604 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc02004e0:	57f5                	li	a5,-3
ffffffffc02004e2:	07fa                	slli	a5,a5,0x1e
ffffffffc02004e4:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc02004e8:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004ea:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ee:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02004f4:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f8:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004fc:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200500:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200506:	8ec9                	or	a3,a3,a0
ffffffffc0200508:	0087979b          	slliw	a5,a5,0x8
ffffffffc020050c:	1b7d                	addi	s6,s6,-1
ffffffffc020050e:	0167f7b3          	and	a5,a5,s6
ffffffffc0200512:	8dd5                	or	a1,a1,a3
ffffffffc0200514:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc0200516:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020051a:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc020051c:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed9a4d>
ffffffffc0200520:	10f59163          	bne	a1,a5,ffffffffc0200622 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc0200524:	471c                	lw	a5,8(a4)
ffffffffc0200526:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc0200528:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020052e:	0086d51b          	srliw	a0,a3,0x8
ffffffffc0200532:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200536:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020053a:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020053e:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200542:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200546:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020054a:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020054e:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200552:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200554:	01146433          	or	s0,s0,a7
ffffffffc0200558:	0086969b          	slliw	a3,a3,0x8
ffffffffc020055c:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200560:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200562:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200566:	8c49                	or	s0,s0,a0
ffffffffc0200568:	0166f6b3          	and	a3,a3,s6
ffffffffc020056c:	00ca6a33          	or	s4,s4,a2
ffffffffc0200570:	0167f7b3          	and	a5,a5,s6
ffffffffc0200574:	8c55                	or	s0,s0,a3
ffffffffc0200576:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020057a:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020057c:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020057e:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200580:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200584:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200586:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200588:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020058c:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020058e:	00002917          	auipc	s2,0x2
ffffffffc0200592:	cb290913          	addi	s2,s2,-846 # ffffffffc0202240 <commands+0x110>
ffffffffc0200596:	49bd                	li	s3,15
        switch (token) {
ffffffffc0200598:	4d91                	li	s11,4
ffffffffc020059a:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020059c:	00002497          	auipc	s1,0x2
ffffffffc02005a0:	c9c48493          	addi	s1,s1,-868 # ffffffffc0202238 <commands+0x108>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc02005a4:	000a2703          	lw	a4,0(s4)
ffffffffc02005a8:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005ac:	0087569b          	srliw	a3,a4,0x8
ffffffffc02005b0:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005b4:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005b8:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005bc:	0107571b          	srliw	a4,a4,0x10
ffffffffc02005c0:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005c2:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005c6:	0087171b          	slliw	a4,a4,0x8
ffffffffc02005ca:	8fd5                	or	a5,a5,a3
ffffffffc02005cc:	00eb7733          	and	a4,s6,a4
ffffffffc02005d0:	8fd9                	or	a5,a5,a4
ffffffffc02005d2:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc02005d4:	09778c63          	beq	a5,s7,ffffffffc020066c <dtb_init+0x1ee>
ffffffffc02005d8:	00fbea63          	bltu	s7,a5,ffffffffc02005ec <dtb_init+0x16e>
ffffffffc02005dc:	07a78663          	beq	a5,s10,ffffffffc0200648 <dtb_init+0x1ca>
ffffffffc02005e0:	4709                	li	a4,2
ffffffffc02005e2:	00e79763          	bne	a5,a4,ffffffffc02005f0 <dtb_init+0x172>
ffffffffc02005e6:	4c81                	li	s9,0
ffffffffc02005e8:	8a56                	mv	s4,s5
ffffffffc02005ea:	bf6d                	j	ffffffffc02005a4 <dtb_init+0x126>
ffffffffc02005ec:	ffb78ee3          	beq	a5,s11,ffffffffc02005e8 <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc02005f0:	00002517          	auipc	a0,0x2
ffffffffc02005f4:	cc850513          	addi	a0,a0,-824 # ffffffffc02022b8 <commands+0x188>
ffffffffc02005f8:	ae1ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02005fc:	00002517          	auipc	a0,0x2
ffffffffc0200600:	cf450513          	addi	a0,a0,-780 # ffffffffc02022f0 <commands+0x1c0>
}
ffffffffc0200604:	7446                	ld	s0,112(sp)
ffffffffc0200606:	70e6                	ld	ra,120(sp)
ffffffffc0200608:	74a6                	ld	s1,104(sp)
ffffffffc020060a:	7906                	ld	s2,96(sp)
ffffffffc020060c:	69e6                	ld	s3,88(sp)
ffffffffc020060e:	6a46                	ld	s4,80(sp)
ffffffffc0200610:	6aa6                	ld	s5,72(sp)
ffffffffc0200612:	6b06                	ld	s6,64(sp)
ffffffffc0200614:	7be2                	ld	s7,56(sp)
ffffffffc0200616:	7c42                	ld	s8,48(sp)
ffffffffc0200618:	7ca2                	ld	s9,40(sp)
ffffffffc020061a:	7d02                	ld	s10,32(sp)
ffffffffc020061c:	6de2                	ld	s11,24(sp)
ffffffffc020061e:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc0200620:	bc65                	j	ffffffffc02000d8 <cprintf>
}
ffffffffc0200622:	7446                	ld	s0,112(sp)
ffffffffc0200624:	70e6                	ld	ra,120(sp)
ffffffffc0200626:	74a6                	ld	s1,104(sp)
ffffffffc0200628:	7906                	ld	s2,96(sp)
ffffffffc020062a:	69e6                	ld	s3,88(sp)
ffffffffc020062c:	6a46                	ld	s4,80(sp)
ffffffffc020062e:	6aa6                	ld	s5,72(sp)
ffffffffc0200630:	6b06                	ld	s6,64(sp)
ffffffffc0200632:	7be2                	ld	s7,56(sp)
ffffffffc0200634:	7c42                	ld	s8,48(sp)
ffffffffc0200636:	7ca2                	ld	s9,40(sp)
ffffffffc0200638:	7d02                	ld	s10,32(sp)
ffffffffc020063a:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc020063c:	00002517          	auipc	a0,0x2
ffffffffc0200640:	bd450513          	addi	a0,a0,-1068 # ffffffffc0202210 <commands+0xe0>
}
ffffffffc0200644:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc0200646:	bc49                	j	ffffffffc02000d8 <cprintf>
                int name_len = strlen(name);
ffffffffc0200648:	8556                	mv	a0,s5
ffffffffc020064a:	7ea010ef          	jal	ra,ffffffffc0201e34 <strlen>
ffffffffc020064e:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200650:	4619                	li	a2,6
ffffffffc0200652:	85a6                	mv	a1,s1
ffffffffc0200654:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc0200656:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200658:	031010ef          	jal	ra,ffffffffc0201e88 <strncmp>
ffffffffc020065c:	e111                	bnez	a0,ffffffffc0200660 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc020065e:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200660:	0a91                	addi	s5,s5,4
ffffffffc0200662:	9ad2                	add	s5,s5,s4
ffffffffc0200664:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200668:	8a56                	mv	s4,s5
ffffffffc020066a:	bf2d                	j	ffffffffc02005a4 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020066c:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200670:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200674:	0087d71b          	srliw	a4,a5,0x8
ffffffffc0200678:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020067c:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200680:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200684:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200688:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020068c:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200690:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200694:	00eaeab3          	or	s5,s5,a4
ffffffffc0200698:	00fb77b3          	and	a5,s6,a5
ffffffffc020069c:	00faeab3          	or	s5,s5,a5
ffffffffc02006a0:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006a2:	000c9c63          	bnez	s9,ffffffffc02006ba <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc02006a6:	1a82                	slli	s5,s5,0x20
ffffffffc02006a8:	00368793          	addi	a5,a3,3
ffffffffc02006ac:	020ada93          	srli	s5,s5,0x20
ffffffffc02006b0:	9abe                	add	s5,s5,a5
ffffffffc02006b2:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc02006b6:	8a56                	mv	s4,s5
ffffffffc02006b8:	b5f5                	j	ffffffffc02005a4 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc02006ba:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006be:	85ca                	mv	a1,s2
ffffffffc02006c0:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006c2:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006c6:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006ca:	0187971b          	slliw	a4,a5,0x18
ffffffffc02006ce:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006d2:	0107d79b          	srliw	a5,a5,0x10
ffffffffc02006d6:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006d8:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006dc:	0087979b          	slliw	a5,a5,0x8
ffffffffc02006e0:	8d59                	or	a0,a0,a4
ffffffffc02006e2:	00fb77b3          	and	a5,s6,a5
ffffffffc02006e6:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc02006e8:	1502                	slli	a0,a0,0x20
ffffffffc02006ea:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006ec:	9522                	add	a0,a0,s0
ffffffffc02006ee:	77c010ef          	jal	ra,ffffffffc0201e6a <strcmp>
ffffffffc02006f2:	66a2                	ld	a3,8(sp)
ffffffffc02006f4:	f94d                	bnez	a0,ffffffffc02006a6 <dtb_init+0x228>
ffffffffc02006f6:	fb59f8e3          	bgeu	s3,s5,ffffffffc02006a6 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02006fa:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02006fe:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200702:	00002517          	auipc	a0,0x2
ffffffffc0200706:	b4650513          	addi	a0,a0,-1210 # ffffffffc0202248 <commands+0x118>
           fdt32_to_cpu(x >> 32);
ffffffffc020070a:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020070e:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc0200712:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200716:	0187de1b          	srliw	t3,a5,0x18
ffffffffc020071a:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020071e:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200722:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200726:	0187d693          	srli	a3,a5,0x18
ffffffffc020072a:	01861f1b          	slliw	t5,a2,0x18
ffffffffc020072e:	0087579b          	srliw	a5,a4,0x8
ffffffffc0200732:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200736:	0106561b          	srliw	a2,a2,0x10
ffffffffc020073a:	010f6f33          	or	t5,t5,a6
ffffffffc020073e:	0187529b          	srliw	t0,a4,0x18
ffffffffc0200742:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200746:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020074a:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020074e:	0186f6b3          	and	a3,a3,s8
ffffffffc0200752:	01859e1b          	slliw	t3,a1,0x18
ffffffffc0200756:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020075a:	0107581b          	srliw	a6,a4,0x10
ffffffffc020075e:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200762:	8361                	srli	a4,a4,0x18
ffffffffc0200764:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200768:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020076c:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200770:	00cb7633          	and	a2,s6,a2
ffffffffc0200774:	0088181b          	slliw	a6,a6,0x8
ffffffffc0200778:	0085959b          	slliw	a1,a1,0x8
ffffffffc020077c:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200780:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200784:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200788:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020078c:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200790:	011b78b3          	and	a7,s6,a7
ffffffffc0200794:	005eeeb3          	or	t4,t4,t0
ffffffffc0200798:	00c6e733          	or	a4,a3,a2
ffffffffc020079c:	006c6c33          	or	s8,s8,t1
ffffffffc02007a0:	010b76b3          	and	a3,s6,a6
ffffffffc02007a4:	00bb7b33          	and	s6,s6,a1
ffffffffc02007a8:	01d7e7b3          	or	a5,a5,t4
ffffffffc02007ac:	016c6b33          	or	s6,s8,s6
ffffffffc02007b0:	01146433          	or	s0,s0,a7
ffffffffc02007b4:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc02007b6:	1702                	slli	a4,a4,0x20
ffffffffc02007b8:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007ba:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007bc:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007be:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007c0:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007c4:	0167eb33          	or	s6,a5,s6
ffffffffc02007c8:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc02007ca:	90fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc02007ce:	85a2                	mv	a1,s0
ffffffffc02007d0:	00002517          	auipc	a0,0x2
ffffffffc02007d4:	a9850513          	addi	a0,a0,-1384 # ffffffffc0202268 <commands+0x138>
ffffffffc02007d8:	901ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc02007dc:	014b5613          	srli	a2,s6,0x14
ffffffffc02007e0:	85da                	mv	a1,s6
ffffffffc02007e2:	00002517          	auipc	a0,0x2
ffffffffc02007e6:	a9e50513          	addi	a0,a0,-1378 # ffffffffc0202280 <commands+0x150>
ffffffffc02007ea:	8efff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc02007ee:	008b05b3          	add	a1,s6,s0
ffffffffc02007f2:	15fd                	addi	a1,a1,-1
ffffffffc02007f4:	00002517          	auipc	a0,0x2
ffffffffc02007f8:	aac50513          	addi	a0,a0,-1364 # ffffffffc02022a0 <commands+0x170>
ffffffffc02007fc:	8ddff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc0200800:	00002517          	auipc	a0,0x2
ffffffffc0200804:	af050513          	addi	a0,a0,-1296 # ffffffffc02022f0 <commands+0x1c0>
        memory_base = mem_base;
ffffffffc0200808:	00006797          	auipc	a5,0x6
ffffffffc020080c:	c487b423          	sd	s0,-952(a5) # ffffffffc0206450 <memory_base>
        memory_size = mem_size;
ffffffffc0200810:	00006797          	auipc	a5,0x6
ffffffffc0200814:	c567b423          	sd	s6,-952(a5) # ffffffffc0206458 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc0200818:	b3f5                	j	ffffffffc0200604 <dtb_init+0x186>

ffffffffc020081a <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc020081a:	00006517          	auipc	a0,0x6
ffffffffc020081e:	c3653503          	ld	a0,-970(a0) # ffffffffc0206450 <memory_base>
ffffffffc0200822:	8082                	ret

ffffffffc0200824 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
}
ffffffffc0200824:	00006517          	auipc	a0,0x6
ffffffffc0200828:	c3453503          	ld	a0,-972(a0) # ffffffffc0206458 <memory_size>
ffffffffc020082c:	8082                	ret

ffffffffc020082e <intr_enable>:
#include <intr.h>
#include <riscv.h>

/* intr_enable - enable irq interrupt */
void intr_enable(void) { set_csr(sstatus, SSTATUS_SIE); }
ffffffffc020082e:	100167f3          	csrrsi	a5,sstatus,2
ffffffffc0200832:	8082                	ret

ffffffffc0200834 <intr_disable>:

/* intr_disable - disable irq interrupt */
void intr_disable(void) { clear_csr(sstatus, SSTATUS_SIE); }
ffffffffc0200834:	100177f3          	csrrci	a5,sstatus,2
ffffffffc0200838:	8082                	ret

ffffffffc020083a <idt_init>:
void idt_init(void) {

    extern void __alltraps(void);
    /* Set sup0 scratch register to 0, indicating to exception vector
       that we are presently executing in the kernel */
    write_csr(sscratch, 0);
ffffffffc020083a:	14005073          	csrwi	sscratch,0
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
ffffffffc020083e:	00000797          	auipc	a5,0x0
ffffffffc0200842:	3ea78793          	addi	a5,a5,1002 # ffffffffc0200c28 <__alltraps>
ffffffffc0200846:	10579073          	csrw	stvec,a5
}
ffffffffc020084a:	8082                	ret

ffffffffc020084c <print_regs>:
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
    cprintf("  cause    0x%08x\n", tf->cause);
}

void print_regs(struct pushregs *gpr) {
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020084c:	610c                	ld	a1,0(a0)
void print_regs(struct pushregs *gpr) {
ffffffffc020084e:	1141                	addi	sp,sp,-16
ffffffffc0200850:	e022                	sd	s0,0(sp)
ffffffffc0200852:	842a                	mv	s0,a0
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc0200854:	00002517          	auipc	a0,0x2
ffffffffc0200858:	ab450513          	addi	a0,a0,-1356 # ffffffffc0202308 <commands+0x1d8>
void print_regs(struct pushregs *gpr) {
ffffffffc020085c:	e406                	sd	ra,8(sp)
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020085e:	87bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  ra       0x%08x\n", gpr->ra);
ffffffffc0200862:	640c                	ld	a1,8(s0)
ffffffffc0200864:	00002517          	auipc	a0,0x2
ffffffffc0200868:	abc50513          	addi	a0,a0,-1348 # ffffffffc0202320 <commands+0x1f0>
ffffffffc020086c:	86dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  sp       0x%08x\n", gpr->sp);
ffffffffc0200870:	680c                	ld	a1,16(s0)
ffffffffc0200872:	00002517          	auipc	a0,0x2
ffffffffc0200876:	ac650513          	addi	a0,a0,-1338 # ffffffffc0202338 <commands+0x208>
ffffffffc020087a:	85fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  gp       0x%08x\n", gpr->gp);
ffffffffc020087e:	6c0c                	ld	a1,24(s0)
ffffffffc0200880:	00002517          	auipc	a0,0x2
ffffffffc0200884:	ad050513          	addi	a0,a0,-1328 # ffffffffc0202350 <commands+0x220>
ffffffffc0200888:	851ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  tp       0x%08x\n", gpr->tp);
ffffffffc020088c:	700c                	ld	a1,32(s0)
ffffffffc020088e:	00002517          	auipc	a0,0x2
ffffffffc0200892:	ada50513          	addi	a0,a0,-1318 # ffffffffc0202368 <commands+0x238>
ffffffffc0200896:	843ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t0       0x%08x\n", gpr->t0);
ffffffffc020089a:	740c                	ld	a1,40(s0)
ffffffffc020089c:	00002517          	auipc	a0,0x2
ffffffffc02008a0:	ae450513          	addi	a0,a0,-1308 # ffffffffc0202380 <commands+0x250>
ffffffffc02008a4:	835ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t1       0x%08x\n", gpr->t1);
ffffffffc02008a8:	780c                	ld	a1,48(s0)
ffffffffc02008aa:	00002517          	auipc	a0,0x2
ffffffffc02008ae:	aee50513          	addi	a0,a0,-1298 # ffffffffc0202398 <commands+0x268>
ffffffffc02008b2:	827ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t2       0x%08x\n", gpr->t2);
ffffffffc02008b6:	7c0c                	ld	a1,56(s0)
ffffffffc02008b8:	00002517          	auipc	a0,0x2
ffffffffc02008bc:	af850513          	addi	a0,a0,-1288 # ffffffffc02023b0 <commands+0x280>
ffffffffc02008c0:	819ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s0       0x%08x\n", gpr->s0);
ffffffffc02008c4:	602c                	ld	a1,64(s0)
ffffffffc02008c6:	00002517          	auipc	a0,0x2
ffffffffc02008ca:	b0250513          	addi	a0,a0,-1278 # ffffffffc02023c8 <commands+0x298>
ffffffffc02008ce:	80bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s1       0x%08x\n", gpr->s1);
ffffffffc02008d2:	642c                	ld	a1,72(s0)
ffffffffc02008d4:	00002517          	auipc	a0,0x2
ffffffffc02008d8:	b0c50513          	addi	a0,a0,-1268 # ffffffffc02023e0 <commands+0x2b0>
ffffffffc02008dc:	ffcff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a0       0x%08x\n", gpr->a0);
ffffffffc02008e0:	682c                	ld	a1,80(s0)
ffffffffc02008e2:	00002517          	auipc	a0,0x2
ffffffffc02008e6:	b1650513          	addi	a0,a0,-1258 # ffffffffc02023f8 <commands+0x2c8>
ffffffffc02008ea:	feeff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a1       0x%08x\n", gpr->a1);
ffffffffc02008ee:	6c2c                	ld	a1,88(s0)
ffffffffc02008f0:	00002517          	auipc	a0,0x2
ffffffffc02008f4:	b2050513          	addi	a0,a0,-1248 # ffffffffc0202410 <commands+0x2e0>
ffffffffc02008f8:	fe0ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a2       0x%08x\n", gpr->a2);
ffffffffc02008fc:	702c                	ld	a1,96(s0)
ffffffffc02008fe:	00002517          	auipc	a0,0x2
ffffffffc0200902:	b2a50513          	addi	a0,a0,-1238 # ffffffffc0202428 <commands+0x2f8>
ffffffffc0200906:	fd2ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a3       0x%08x\n", gpr->a3);
ffffffffc020090a:	742c                	ld	a1,104(s0)
ffffffffc020090c:	00002517          	auipc	a0,0x2
ffffffffc0200910:	b3450513          	addi	a0,a0,-1228 # ffffffffc0202440 <commands+0x310>
ffffffffc0200914:	fc4ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a4       0x%08x\n", gpr->a4);
ffffffffc0200918:	782c                	ld	a1,112(s0)
ffffffffc020091a:	00002517          	auipc	a0,0x2
ffffffffc020091e:	b3e50513          	addi	a0,a0,-1218 # ffffffffc0202458 <commands+0x328>
ffffffffc0200922:	fb6ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a5       0x%08x\n", gpr->a5);
ffffffffc0200926:	7c2c                	ld	a1,120(s0)
ffffffffc0200928:	00002517          	auipc	a0,0x2
ffffffffc020092c:	b4850513          	addi	a0,a0,-1208 # ffffffffc0202470 <commands+0x340>
ffffffffc0200930:	fa8ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a6       0x%08x\n", gpr->a6);
ffffffffc0200934:	604c                	ld	a1,128(s0)
ffffffffc0200936:	00002517          	auipc	a0,0x2
ffffffffc020093a:	b5250513          	addi	a0,a0,-1198 # ffffffffc0202488 <commands+0x358>
ffffffffc020093e:	f9aff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a7       0x%08x\n", gpr->a7);
ffffffffc0200942:	644c                	ld	a1,136(s0)
ffffffffc0200944:	00002517          	auipc	a0,0x2
ffffffffc0200948:	b5c50513          	addi	a0,a0,-1188 # ffffffffc02024a0 <commands+0x370>
ffffffffc020094c:	f8cff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s2       0x%08x\n", gpr->s2);
ffffffffc0200950:	684c                	ld	a1,144(s0)
ffffffffc0200952:	00002517          	auipc	a0,0x2
ffffffffc0200956:	b6650513          	addi	a0,a0,-1178 # ffffffffc02024b8 <commands+0x388>
ffffffffc020095a:	f7eff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s3       0x%08x\n", gpr->s3);
ffffffffc020095e:	6c4c                	ld	a1,152(s0)
ffffffffc0200960:	00002517          	auipc	a0,0x2
ffffffffc0200964:	b7050513          	addi	a0,a0,-1168 # ffffffffc02024d0 <commands+0x3a0>
ffffffffc0200968:	f70ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s4       0x%08x\n", gpr->s4);
ffffffffc020096c:	704c                	ld	a1,160(s0)
ffffffffc020096e:	00002517          	auipc	a0,0x2
ffffffffc0200972:	b7a50513          	addi	a0,a0,-1158 # ffffffffc02024e8 <commands+0x3b8>
ffffffffc0200976:	f62ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s5       0x%08x\n", gpr->s5);
ffffffffc020097a:	744c                	ld	a1,168(s0)
ffffffffc020097c:	00002517          	auipc	a0,0x2
ffffffffc0200980:	b8450513          	addi	a0,a0,-1148 # ffffffffc0202500 <commands+0x3d0>
ffffffffc0200984:	f54ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s6       0x%08x\n", gpr->s6);
ffffffffc0200988:	784c                	ld	a1,176(s0)
ffffffffc020098a:	00002517          	auipc	a0,0x2
ffffffffc020098e:	b8e50513          	addi	a0,a0,-1138 # ffffffffc0202518 <commands+0x3e8>
ffffffffc0200992:	f46ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s7       0x%08x\n", gpr->s7);
ffffffffc0200996:	7c4c                	ld	a1,184(s0)
ffffffffc0200998:	00002517          	auipc	a0,0x2
ffffffffc020099c:	b9850513          	addi	a0,a0,-1128 # ffffffffc0202530 <commands+0x400>
ffffffffc02009a0:	f38ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s8       0x%08x\n", gpr->s8);
ffffffffc02009a4:	606c                	ld	a1,192(s0)
ffffffffc02009a6:	00002517          	auipc	a0,0x2
ffffffffc02009aa:	ba250513          	addi	a0,a0,-1118 # ffffffffc0202548 <commands+0x418>
ffffffffc02009ae:	f2aff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s9       0x%08x\n", gpr->s9);
ffffffffc02009b2:	646c                	ld	a1,200(s0)
ffffffffc02009b4:	00002517          	auipc	a0,0x2
ffffffffc02009b8:	bac50513          	addi	a0,a0,-1108 # ffffffffc0202560 <commands+0x430>
ffffffffc02009bc:	f1cff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s10      0x%08x\n", gpr->s10);
ffffffffc02009c0:	686c                	ld	a1,208(s0)
ffffffffc02009c2:	00002517          	auipc	a0,0x2
ffffffffc02009c6:	bb650513          	addi	a0,a0,-1098 # ffffffffc0202578 <commands+0x448>
ffffffffc02009ca:	f0eff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s11      0x%08x\n", gpr->s11);
ffffffffc02009ce:	6c6c                	ld	a1,216(s0)
ffffffffc02009d0:	00002517          	auipc	a0,0x2
ffffffffc02009d4:	bc050513          	addi	a0,a0,-1088 # ffffffffc0202590 <commands+0x460>
ffffffffc02009d8:	f00ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t3       0x%08x\n", gpr->t3);
ffffffffc02009dc:	706c                	ld	a1,224(s0)
ffffffffc02009de:	00002517          	auipc	a0,0x2
ffffffffc02009e2:	bca50513          	addi	a0,a0,-1078 # ffffffffc02025a8 <commands+0x478>
ffffffffc02009e6:	ef2ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t4       0x%08x\n", gpr->t4);
ffffffffc02009ea:	746c                	ld	a1,232(s0)
ffffffffc02009ec:	00002517          	auipc	a0,0x2
ffffffffc02009f0:	bd450513          	addi	a0,a0,-1068 # ffffffffc02025c0 <commands+0x490>
ffffffffc02009f4:	ee4ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t5       0x%08x\n", gpr->t5);
ffffffffc02009f8:	786c                	ld	a1,240(s0)
ffffffffc02009fa:	00002517          	auipc	a0,0x2
ffffffffc02009fe:	bde50513          	addi	a0,a0,-1058 # ffffffffc02025d8 <commands+0x4a8>
ffffffffc0200a02:	ed6ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a06:	7c6c                	ld	a1,248(s0)
}
ffffffffc0200a08:	6402                	ld	s0,0(sp)
ffffffffc0200a0a:	60a2                	ld	ra,8(sp)
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a0c:	00002517          	auipc	a0,0x2
ffffffffc0200a10:	be450513          	addi	a0,a0,-1052 # ffffffffc02025f0 <commands+0x4c0>
}
ffffffffc0200a14:	0141                	addi	sp,sp,16
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a16:	ec2ff06f          	j	ffffffffc02000d8 <cprintf>

ffffffffc0200a1a <print_trapframe>:
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a1a:	1141                	addi	sp,sp,-16
ffffffffc0200a1c:	e022                	sd	s0,0(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a1e:	85aa                	mv	a1,a0
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a20:	842a                	mv	s0,a0
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a22:	00002517          	auipc	a0,0x2
ffffffffc0200a26:	be650513          	addi	a0,a0,-1050 # ffffffffc0202608 <commands+0x4d8>
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a2a:	e406                	sd	ra,8(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a2c:	eacff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    print_regs(&tf->gpr);
ffffffffc0200a30:	8522                	mv	a0,s0
ffffffffc0200a32:	e1bff0ef          	jal	ra,ffffffffc020084c <print_regs>
    cprintf("  status   0x%08x\n", tf->status);
ffffffffc0200a36:	10043583          	ld	a1,256(s0)
ffffffffc0200a3a:	00002517          	auipc	a0,0x2
ffffffffc0200a3e:	be650513          	addi	a0,a0,-1050 # ffffffffc0202620 <commands+0x4f0>
ffffffffc0200a42:	e96ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  epc      0x%08x\n", tf->epc);
ffffffffc0200a46:	10843583          	ld	a1,264(s0)
ffffffffc0200a4a:	00002517          	auipc	a0,0x2
ffffffffc0200a4e:	bee50513          	addi	a0,a0,-1042 # ffffffffc0202638 <commands+0x508>
ffffffffc0200a52:	e86ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
ffffffffc0200a56:	11043583          	ld	a1,272(s0)
ffffffffc0200a5a:	00002517          	auipc	a0,0x2
ffffffffc0200a5e:	bf650513          	addi	a0,a0,-1034 # ffffffffc0202650 <commands+0x520>
ffffffffc0200a62:	e76ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a66:	11843583          	ld	a1,280(s0)
}
ffffffffc0200a6a:	6402                	ld	s0,0(sp)
ffffffffc0200a6c:	60a2                	ld	ra,8(sp)
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a6e:	00002517          	auipc	a0,0x2
ffffffffc0200a72:	bfa50513          	addi	a0,a0,-1030 # ffffffffc0202668 <commands+0x538>
}
ffffffffc0200a76:	0141                	addi	sp,sp,16
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a78:	e60ff06f          	j	ffffffffc02000d8 <cprintf>

ffffffffc0200a7c <interrupt_handler>:

// lab3 function2 2410721
void interrupt_handler(struct trapframe *tf) {
    uintptr_t interrupt = tf->cause & ~((uintptr_t)1 << (__riscv_xlen - 1));
ffffffffc0200a7c:	11853583          	ld	a1,280(a0)
void interrupt_handler(struct trapframe *tf) {
ffffffffc0200a80:	1141                	addi	sp,sp,-16
ffffffffc0200a82:	e406                	sd	ra,8(sp)
    uintptr_t interrupt = tf->cause & ~((uintptr_t)1 << (__riscv_xlen - 1));
ffffffffc0200a84:	0586                	slli	a1,a1,0x1
void interrupt_handler(struct trapframe *tf) {
ffffffffc0200a86:	e022                	sd	s0,0(sp)
ffffffffc0200a88:	47ad                	li	a5,11
    uintptr_t interrupt = tf->cause & ~((uintptr_t)1 << (__riscv_xlen - 1));
ffffffffc0200a8a:	8185                	srli	a1,a1,0x1

    switch (interrupt) {
ffffffffc0200a8c:	0ab7e963          	bltu	a5,a1,ffffffffc0200b3e <interrupt_handler+0xc2>
ffffffffc0200a90:	00002717          	auipc	a4,0x2
ffffffffc0200a94:	da070713          	addi	a4,a4,-608 # ffffffffc0202830 <commands+0x700>
ffffffffc0200a98:	058a                	slli	a1,a1,0x2
ffffffffc0200a9a:	95ba                	add	a1,a1,a4
ffffffffc0200a9c:	419c                	lw	a5,0(a1)
ffffffffc0200a9e:	97ba                	add	a5,a5,a4
ffffffffc0200aa0:	8782                	jr	a5
        break;
    case IRQ_S_EXT:
        cprintf("Supervisor external interrupt\n");
        break;
    case IRQ_H_EXT:
        cprintf("Hypervisor external interrupt\n");
ffffffffc0200aa2:	00002517          	auipc	a0,0x2
ffffffffc0200aa6:	d2e50513          	addi	a0,a0,-722 # ffffffffc02027d0 <commands+0x6a0>
    default:
        cprintf("Unknown interrupt: cause %d\n", (int)interrupt);
        print_trapframe(tf);
        break;
    }
}
ffffffffc0200aaa:	6402                	ld	s0,0(sp)
ffffffffc0200aac:	60a2                	ld	ra,8(sp)
ffffffffc0200aae:	0141                	addi	sp,sp,16
        cprintf("Supervisor software interrupt\n");
ffffffffc0200ab0:	e28ff06f          	j	ffffffffc02000d8 <cprintf>
        cprintf("Machine external interrupt\n");
ffffffffc0200ab4:	00002517          	auipc	a0,0x2
ffffffffc0200ab8:	d3c50513          	addi	a0,a0,-708 # ffffffffc02027f0 <commands+0x6c0>
ffffffffc0200abc:	b7fd                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("User software interrupt\n");
ffffffffc0200abe:	00002517          	auipc	a0,0x2
ffffffffc0200ac2:	bc250513          	addi	a0,a0,-1086 # ffffffffc0202680 <commands+0x550>
ffffffffc0200ac6:	b7d5                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Supervisor software interrupt\n");
ffffffffc0200ac8:	00002517          	auipc	a0,0x2
ffffffffc0200acc:	bd850513          	addi	a0,a0,-1064 # ffffffffc02026a0 <commands+0x570>
ffffffffc0200ad0:	bfe9                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Hypervisor software interrupt\n");
ffffffffc0200ad2:	00002517          	auipc	a0,0x2
ffffffffc0200ad6:	bee50513          	addi	a0,a0,-1042 # ffffffffc02026c0 <commands+0x590>
ffffffffc0200ada:	bfc1                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Machine software interrupt\n");
ffffffffc0200adc:	00002517          	auipc	a0,0x2
ffffffffc0200ae0:	c0450513          	addi	a0,a0,-1020 # ffffffffc02026e0 <commands+0x5b0>
ffffffffc0200ae4:	b7d9                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("User timer interrupt\n");
ffffffffc0200ae6:	00002517          	auipc	a0,0x2
ffffffffc0200aea:	c1a50513          	addi	a0,a0,-998 # ffffffffc0202700 <commands+0x5d0>
ffffffffc0200aee:	bf75                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        clock_set_next_event();
ffffffffc0200af0:	971ff0ef          	jal	ra,ffffffffc0200460 <clock_set_next_event>
        ticks++;
ffffffffc0200af4:	00006797          	auipc	a5,0x6
ffffffffc0200af8:	95478793          	addi	a5,a5,-1708 # ffffffffc0206448 <ticks>
ffffffffc0200afc:	6398                	ld	a4,0(a5)
ffffffffc0200afe:	0705                	addi	a4,a4,1
ffffffffc0200b00:	e398                	sd	a4,0(a5)
        if (ticks % TICK_NUM == 0) {
ffffffffc0200b02:	639c                	ld	a5,0(a5)
ffffffffc0200b04:	06400713          	li	a4,100
ffffffffc0200b08:	02e7f7b3          	remu	a5,a5,a4
ffffffffc0200b0c:	c7b1                	beqz	a5,ffffffffc0200b58 <interrupt_handler+0xdc>
}
ffffffffc0200b0e:	60a2                	ld	ra,8(sp)
ffffffffc0200b10:	6402                	ld	s0,0(sp)
ffffffffc0200b12:	0141                	addi	sp,sp,16
ffffffffc0200b14:	8082                	ret
        cprintf("Hypervisor timer interrupt\n");
ffffffffc0200b16:	00002517          	auipc	a0,0x2
ffffffffc0200b1a:	c3a50513          	addi	a0,a0,-966 # ffffffffc0202750 <commands+0x620>
ffffffffc0200b1e:	b771                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Machine timer interrupt\n");
ffffffffc0200b20:	00002517          	auipc	a0,0x2
ffffffffc0200b24:	c5050513          	addi	a0,a0,-944 # ffffffffc0202770 <commands+0x640>
ffffffffc0200b28:	b749                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("User external interrupt\n");
ffffffffc0200b2a:	00002517          	auipc	a0,0x2
ffffffffc0200b2e:	c6650513          	addi	a0,a0,-922 # ffffffffc0202790 <commands+0x660>
ffffffffc0200b32:	bfa5                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Supervisor external interrupt\n");
ffffffffc0200b34:	00002517          	auipc	a0,0x2
ffffffffc0200b38:	c7c50513          	addi	a0,a0,-900 # ffffffffc02027b0 <commands+0x680>
ffffffffc0200b3c:	b7bd                	j	ffffffffc0200aaa <interrupt_handler+0x2e>
        cprintf("Unknown interrupt: cause %d\n", (int)interrupt);
ffffffffc0200b3e:	842a                	mv	s0,a0
ffffffffc0200b40:	2581                	sext.w	a1,a1
ffffffffc0200b42:	00002517          	auipc	a0,0x2
ffffffffc0200b46:	cce50513          	addi	a0,a0,-818 # ffffffffc0202810 <commands+0x6e0>
ffffffffc0200b4a:	d8eff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        print_trapframe(tf);
ffffffffc0200b4e:	8522                	mv	a0,s0
}
ffffffffc0200b50:	6402                	ld	s0,0(sp)
ffffffffc0200b52:	60a2                	ld	ra,8(sp)
ffffffffc0200b54:	0141                	addi	sp,sp,16
        print_trapframe(tf);
ffffffffc0200b56:	b5d1                	j	ffffffffc0200a1a <print_trapframe>
    cprintf("%d ticks\n", TICK_NUM);
ffffffffc0200b58:	06400593          	li	a1,100
ffffffffc0200b5c:	00002517          	auipc	a0,0x2
ffffffffc0200b60:	bbc50513          	addi	a0,a0,-1092 # ffffffffc0202718 <commands+0x5e8>
ffffffffc0200b64:	d74ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
            printed++;
ffffffffc0200b68:	00006717          	auipc	a4,0x6
ffffffffc0200b6c:	8f870713          	addi	a4,a4,-1800 # ffffffffc0206460 <printed.0>
ffffffffc0200b70:	631c                	ld	a5,0(a4)
            if (printed >= SHUTDOWN_AFTER) {
ffffffffc0200b72:	46a5                	li	a3,9
            printed++;
ffffffffc0200b74:	0785                	addi	a5,a5,1
ffffffffc0200b76:	e31c                	sd	a5,0(a4)
            if (printed >= SHUTDOWN_AFTER) {
ffffffffc0200b78:	f8f6fbe3          	bgeu	a3,a5,ffffffffc0200b0e <interrupt_handler+0x92>
                cprintf("timer test complete, shutting down\n");
ffffffffc0200b7c:	00002517          	auipc	a0,0x2
ffffffffc0200b80:	bac50513          	addi	a0,a0,-1108 # ffffffffc0202728 <commands+0x5f8>
ffffffffc0200b84:	d54ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
}
ffffffffc0200b88:	6402                	ld	s0,0(sp)
ffffffffc0200b8a:	60a2                	ld	ra,8(sp)
ffffffffc0200b8c:	0141                	addi	sp,sp,16
                sbi_shutdown();
ffffffffc0200b8e:	28c0106f          	j	ffffffffc0201e1a <sbi_shutdown>

ffffffffc0200b92 <exception_handler>:

// lab3 function2 2411061
void exception_handler(struct trapframe *tf) {
ffffffffc0200b92:	1101                	addi	sp,sp,-32
ffffffffc0200b94:	e426                	sd	s1,8(sp)
    switch (tf->cause) {
ffffffffc0200b96:	11853483          	ld	s1,280(a0)
void exception_handler(struct trapframe *tf) {
ffffffffc0200b9a:	e822                	sd	s0,16(sp)
ffffffffc0200b9c:	ec06                	sd	ra,24(sp)
    switch (tf->cause) {
ffffffffc0200b9e:	4789                	li	a5,2
void exception_handler(struct trapframe *tf) {
ffffffffc0200ba0:	842a                	mv	s0,a0
    switch (tf->cause) {
ffffffffc0200ba2:	00f48a63          	beq	s1,a5,ffffffffc0200bb6 <exception_handler+0x24>
ffffffffc0200ba6:	478d                	li	a5,3
ffffffffc0200ba8:	04f48063          	beq	s1,a5,ffffffffc0200be8 <exception_handler+0x56>
        break;
    default:
        print_trapframe(tf);
        break;
    }
}
ffffffffc0200bac:	6442                	ld	s0,16(sp)
ffffffffc0200bae:	60e2                	ld	ra,24(sp)
ffffffffc0200bb0:	64a2                	ld	s1,8(sp)
ffffffffc0200bb2:	6105                	addi	sp,sp,32
        print_trapframe(tf);
ffffffffc0200bb4:	b59d                	j	ffffffffc0200a1a <print_trapframe>
        cprintf("Illegal instruction at 0x%08x\n", tf->epc);
ffffffffc0200bb6:	10853583          	ld	a1,264(a0)
ffffffffc0200bba:	00002517          	auipc	a0,0x2
ffffffffc0200bbe:	ca650513          	addi	a0,a0,-858 # ffffffffc0202860 <commands+0x730>
ffffffffc0200bc2:	d16ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        tf->epc += ((*(const uint16_t *)tf->epc & 0x3) == 0x3) ? 4 : 2;
ffffffffc0200bc6:	10843783          	ld	a5,264(s0)
ffffffffc0200bca:	468d                	li	a3,3
ffffffffc0200bcc:	0007d703          	lhu	a4,0(a5)
ffffffffc0200bd0:	8b0d                	andi	a4,a4,3
ffffffffc0200bd2:	00d71363          	bne	a4,a3,ffffffffc0200bd8 <exception_handler+0x46>
ffffffffc0200bd6:	4491                	li	s1,4
ffffffffc0200bd8:	97a6                	add	a5,a5,s1
}
ffffffffc0200bda:	60e2                	ld	ra,24(sp)
        tf->epc += ((*(const uint16_t *)tf->epc & 0x3) == 0x3) ? 4 : 2;
ffffffffc0200bdc:	10f43423          	sd	a5,264(s0)
}
ffffffffc0200be0:	6442                	ld	s0,16(sp)
ffffffffc0200be2:	64a2                	ld	s1,8(sp)
ffffffffc0200be4:	6105                	addi	sp,sp,32
ffffffffc0200be6:	8082                	ret
        cprintf("Breakpoint at 0x%08x\n", tf->epc);
ffffffffc0200be8:	10853583          	ld	a1,264(a0)
ffffffffc0200bec:	00002517          	auipc	a0,0x2
ffffffffc0200bf0:	c9450513          	addi	a0,a0,-876 # ffffffffc0202880 <commands+0x750>
ffffffffc0200bf4:	ce4ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        tf->epc += ((*(const uint16_t *)tf->epc & 0x3) == 0x3) ? 4 : 2;
ffffffffc0200bf8:	10843783          	ld	a5,264(s0)
ffffffffc0200bfc:	4691                	li	a3,4
ffffffffc0200bfe:	0007d703          	lhu	a4,0(a5)
ffffffffc0200c02:	8b0d                	andi	a4,a4,3
ffffffffc0200c04:	00970363          	beq	a4,s1,ffffffffc0200c0a <exception_handler+0x78>
ffffffffc0200c08:	4689                	li	a3,2
ffffffffc0200c0a:	97b6                	add	a5,a5,a3
}
ffffffffc0200c0c:	60e2                	ld	ra,24(sp)
        tf->epc += ((*(const uint16_t *)tf->epc & 0x3) == 0x3) ? 4 : 2;
ffffffffc0200c0e:	10f43423          	sd	a5,264(s0)
}
ffffffffc0200c12:	6442                	ld	s0,16(sp)
ffffffffc0200c14:	64a2                	ld	s1,8(sp)
ffffffffc0200c16:	6105                	addi	sp,sp,32
ffffffffc0200c18:	8082                	ret

ffffffffc0200c1a <trap>:


static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
ffffffffc0200c1a:	11853783          	ld	a5,280(a0)
ffffffffc0200c1e:	0007c363          	bltz	a5,ffffffffc0200c24 <trap+0xa>
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
ffffffffc0200c22:	bf85                	j	ffffffffc0200b92 <exception_handler>
        interrupt_handler(tf);
ffffffffc0200c24:	bda1                	j	ffffffffc0200a7c <interrupt_handler>
	...

ffffffffc0200c28 <__alltraps>:
    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL
ffffffffc0200c28:	14011073          	csrw	sscratch,sp
ffffffffc0200c2c:	712d                	addi	sp,sp,-288
ffffffffc0200c2e:	e002                	sd	zero,0(sp)
ffffffffc0200c30:	e406                	sd	ra,8(sp)
ffffffffc0200c32:	ec0e                	sd	gp,24(sp)
ffffffffc0200c34:	f012                	sd	tp,32(sp)
ffffffffc0200c36:	f416                	sd	t0,40(sp)
ffffffffc0200c38:	f81a                	sd	t1,48(sp)
ffffffffc0200c3a:	fc1e                	sd	t2,56(sp)
ffffffffc0200c3c:	e0a2                	sd	s0,64(sp)
ffffffffc0200c3e:	e4a6                	sd	s1,72(sp)
ffffffffc0200c40:	e8aa                	sd	a0,80(sp)
ffffffffc0200c42:	ecae                	sd	a1,88(sp)
ffffffffc0200c44:	f0b2                	sd	a2,96(sp)
ffffffffc0200c46:	f4b6                	sd	a3,104(sp)
ffffffffc0200c48:	f8ba                	sd	a4,112(sp)
ffffffffc0200c4a:	fcbe                	sd	a5,120(sp)
ffffffffc0200c4c:	e142                	sd	a6,128(sp)
ffffffffc0200c4e:	e546                	sd	a7,136(sp)
ffffffffc0200c50:	e94a                	sd	s2,144(sp)
ffffffffc0200c52:	ed4e                	sd	s3,152(sp)
ffffffffc0200c54:	f152                	sd	s4,160(sp)
ffffffffc0200c56:	f556                	sd	s5,168(sp)
ffffffffc0200c58:	f95a                	sd	s6,176(sp)
ffffffffc0200c5a:	fd5e                	sd	s7,184(sp)
ffffffffc0200c5c:	e1e2                	sd	s8,192(sp)
ffffffffc0200c5e:	e5e6                	sd	s9,200(sp)
ffffffffc0200c60:	e9ea                	sd	s10,208(sp)
ffffffffc0200c62:	edee                	sd	s11,216(sp)
ffffffffc0200c64:	f1f2                	sd	t3,224(sp)
ffffffffc0200c66:	f5f6                	sd	t4,232(sp)
ffffffffc0200c68:	f9fa                	sd	t5,240(sp)
ffffffffc0200c6a:	fdfe                	sd	t6,248(sp)
ffffffffc0200c6c:	14001473          	csrrw	s0,sscratch,zero
ffffffffc0200c70:	100024f3          	csrr	s1,sstatus
ffffffffc0200c74:	14102973          	csrr	s2,sepc
ffffffffc0200c78:	143029f3          	csrr	s3,stval
ffffffffc0200c7c:	14202a73          	csrr	s4,scause
ffffffffc0200c80:	e822                	sd	s0,16(sp)
ffffffffc0200c82:	e226                	sd	s1,256(sp)
ffffffffc0200c84:	e64a                	sd	s2,264(sp)
ffffffffc0200c86:	ea4e                	sd	s3,272(sp)
ffffffffc0200c88:	ee52                	sd	s4,280(sp)

    #lab3 function1 2414166
    # a0 is the first C argument: the trapframe starts at the current sp.
    mv a0, sp
ffffffffc0200c8a:	850a                	mv	a0,sp
    call trap
ffffffffc0200c8c:	f8fff0ef          	jal	ra,ffffffffc0200c1a <trap>

ffffffffc0200c90 <__trapret>:
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
ffffffffc0200c90:	6292                	ld	t0,256(sp)
ffffffffc0200c92:	6332                	ld	t1,264(sp)
ffffffffc0200c94:	10029073          	csrw	sstatus,t0
ffffffffc0200c98:	14131073          	csrw	sepc,t1
ffffffffc0200c9c:	60a2                	ld	ra,8(sp)
ffffffffc0200c9e:	61e2                	ld	gp,24(sp)
ffffffffc0200ca0:	7202                	ld	tp,32(sp)
ffffffffc0200ca2:	72a2                	ld	t0,40(sp)
ffffffffc0200ca4:	7342                	ld	t1,48(sp)
ffffffffc0200ca6:	73e2                	ld	t2,56(sp)
ffffffffc0200ca8:	6406                	ld	s0,64(sp)
ffffffffc0200caa:	64a6                	ld	s1,72(sp)
ffffffffc0200cac:	6546                	ld	a0,80(sp)
ffffffffc0200cae:	65e6                	ld	a1,88(sp)
ffffffffc0200cb0:	7606                	ld	a2,96(sp)
ffffffffc0200cb2:	76a6                	ld	a3,104(sp)
ffffffffc0200cb4:	7746                	ld	a4,112(sp)
ffffffffc0200cb6:	77e6                	ld	a5,120(sp)
ffffffffc0200cb8:	680a                	ld	a6,128(sp)
ffffffffc0200cba:	68aa                	ld	a7,136(sp)
ffffffffc0200cbc:	694a                	ld	s2,144(sp)
ffffffffc0200cbe:	69ea                	ld	s3,152(sp)
ffffffffc0200cc0:	7a0a                	ld	s4,160(sp)
ffffffffc0200cc2:	7aaa                	ld	s5,168(sp)
ffffffffc0200cc4:	7b4a                	ld	s6,176(sp)
ffffffffc0200cc6:	7bea                	ld	s7,184(sp)
ffffffffc0200cc8:	6c0e                	ld	s8,192(sp)
ffffffffc0200cca:	6cae                	ld	s9,200(sp)
ffffffffc0200ccc:	6d4e                	ld	s10,208(sp)
ffffffffc0200cce:	6dee                	ld	s11,216(sp)
ffffffffc0200cd0:	7e0e                	ld	t3,224(sp)
ffffffffc0200cd2:	7eae                	ld	t4,232(sp)
ffffffffc0200cd4:	7f4e                	ld	t5,240(sp)
ffffffffc0200cd6:	7fee                	ld	t6,248(sp)
ffffffffc0200cd8:	6142                	ld	sp,16(sp)
    # return from supervisor call
    sret
ffffffffc0200cda:	10200073          	sret

ffffffffc0200cde <best_fit_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc0200cde:	00005797          	auipc	a5,0x5
ffffffffc0200ce2:	34a78793          	addi	a5,a5,842 # ffffffffc0206028 <free_area>
ffffffffc0200ce6:	e79c                	sd	a5,8(a5)
ffffffffc0200ce8:	e39c                	sd	a5,0(a5)
static void best_fit_check(void);

static void
best_fit_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc0200cea:	0007a823          	sw	zero,16(a5)
}
ffffffffc0200cee:	8082                	ret

ffffffffc0200cf0 <best_fit_insert_block>:
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200cf0:	00005697          	auipc	a3,0x5
ffffffffc0200cf4:	33868693          	addi	a3,a3,824 # ffffffffc0206028 <free_area>
ffffffffc0200cf8:	669c                	ld	a5,8(a3)

/* Insert by address, then coalesce physical neighbours. */
static void
best_fit_insert_block(struct Page *base) {
    list_entry_t *le = list_next(&free_list);
    while (le != &free_list && le2page(le, page_link) < base) {
ffffffffc0200cfa:	00d78b63          	beq	a5,a3,ffffffffc0200d10 <best_fit_insert_block+0x20>
ffffffffc0200cfe:	fe878713          	addi	a4,a5,-24
ffffffffc0200d02:	00a77763          	bgeu	a4,a0,ffffffffc0200d10 <best_fit_insert_block+0x20>
ffffffffc0200d06:	679c                	ld	a5,8(a5)
ffffffffc0200d08:	fe878713          	addi	a4,a5,-24
ffffffffc0200d0c:	fed79be3          	bne	a5,a3,ffffffffc0200d02 <best_fit_insert_block+0x12>
    __list_add(elm, listelm->prev, listelm);
ffffffffc0200d10:	6398                	ld	a4,0(a5)
        le = list_next(le);
    }
    list_add_before(le, &base->page_link);
ffffffffc0200d12:	01850593          	addi	a1,a0,24
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc0200d16:	e38c                	sd	a1,0(a5)
ffffffffc0200d18:	e70c                	sd	a1,8(a4)
    elm->next = next;
ffffffffc0200d1a:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0200d1c:	ed18                	sd	a4,24(a0)

    le = list_prev(&base->page_link);
    if (le != &free_list) {
ffffffffc0200d1e:	02d70163          	beq	a4,a3,ffffffffc0200d40 <best_fit_insert_block+0x50>
        struct Page *prev = le2page(le, page_link);
        if (prev + prev->property == base) {
ffffffffc0200d22:	ff872303          	lw	t1,-8(a4)
        struct Page *prev = le2page(le, page_link);
ffffffffc0200d26:	fe870893          	addi	a7,a4,-24
        if (prev + prev->property == base) {
ffffffffc0200d2a:	02031813          	slli	a6,t1,0x20
ffffffffc0200d2e:	02085813          	srli	a6,a6,0x20
ffffffffc0200d32:	00281613          	slli	a2,a6,0x2
ffffffffc0200d36:	9642                	add	a2,a2,a6
ffffffffc0200d38:	060e                	slli	a2,a2,0x3
ffffffffc0200d3a:	9646                	add	a2,a2,a7
ffffffffc0200d3c:	04c50463          	beq	a0,a2,ffffffffc0200d84 <best_fit_insert_block+0x94>
            list_del_init(&base->page_link);
            base = prev;
        }
    }
    le = list_next(&base->page_link);
    if (le != &free_list) {
ffffffffc0200d40:	00d78f63          	beq	a5,a3,ffffffffc0200d5e <best_fit_insert_block+0x6e>
        struct Page *next = le2page(le, page_link);
        if (base + base->property == next) {
ffffffffc0200d44:	490c                	lw	a1,16(a0)
        struct Page *next = le2page(le, page_link);
ffffffffc0200d46:	fe878693          	addi	a3,a5,-24
        if (base + base->property == next) {
ffffffffc0200d4a:	02059613          	slli	a2,a1,0x20
ffffffffc0200d4e:	9201                	srli	a2,a2,0x20
ffffffffc0200d50:	00261713          	slli	a4,a2,0x2
ffffffffc0200d54:	9732                	add	a4,a4,a2
ffffffffc0200d56:	070e                	slli	a4,a4,0x3
ffffffffc0200d58:	972a                	add	a4,a4,a0
ffffffffc0200d5a:	00d70363          	beq	a4,a3,ffffffffc0200d60 <best_fit_insert_block+0x70>
            ClearPageProperty(next);
            next->property = 0;
            list_del_init(&next->page_link);
        }
    }
}
ffffffffc0200d5e:	8082                	ret
            base->property += next->property;
ffffffffc0200d60:	ff87a703          	lw	a4,-8(a5)
 * clear_bit - Atomically clears a bit in memory
 * @nr:     the bit to clear
 * @addr:   the address to start counting from
 * */
static inline void clear_bit(int nr, volatile void *addr) {
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc0200d64:	ff078693          	addi	a3,a5,-16
ffffffffc0200d68:	9db9                	addw	a1,a1,a4
ffffffffc0200d6a:	c90c                	sw	a1,16(a0)
ffffffffc0200d6c:	5775                	li	a4,-3
ffffffffc0200d6e:	60e6b02f          	amoand.d	zero,a4,(a3)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200d72:	6394                	ld	a3,0(a5)
ffffffffc0200d74:	6798                	ld	a4,8(a5)
            next->property = 0;
ffffffffc0200d76:	fe07ac23          	sw	zero,-8(a5)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc0200d7a:	e698                	sd	a4,8(a3)
    next->prev = prev;
ffffffffc0200d7c:	e314                	sd	a3,0(a4)
    elm->prev = elm->next = elm;
ffffffffc0200d7e:	e79c                	sd	a5,8(a5)
ffffffffc0200d80:	e39c                	sd	a5,0(a5)
}
ffffffffc0200d82:	8082                	ret
            prev->property += base->property;
ffffffffc0200d84:	491c                	lw	a5,16(a0)
ffffffffc0200d86:	00850613          	addi	a2,a0,8
ffffffffc0200d8a:	0067833b          	addw	t1,a5,t1
ffffffffc0200d8e:	fe672c23          	sw	t1,-8(a4)
ffffffffc0200d92:	57f5                	li	a5,-3
ffffffffc0200d94:	60f6302f          	amoand.d	zero,a5,(a2)
    __list_del(listelm->prev, listelm->next);
ffffffffc0200d98:	711c                	ld	a5,32(a0)
ffffffffc0200d9a:	6d10                	ld	a2,24(a0)
            base->property = 0;
ffffffffc0200d9c:	00052823          	sw	zero,16(a0)
    prev->next = next;
ffffffffc0200da0:	e61c                	sd	a5,8(a2)
    next->prev = prev;
ffffffffc0200da2:	e390                	sd	a2,0(a5)
    elm->prev = elm->next = elm;
ffffffffc0200da4:	f10c                	sd	a1,32(a0)
    return listelm->next;
ffffffffc0200da6:	671c                	ld	a5,8(a4)
    elm->prev = elm->next = elm;
ffffffffc0200da8:	ed0c                	sd	a1,24(a0)
            base = prev;
ffffffffc0200daa:	8546                	mv	a0,a7
ffffffffc0200dac:	bf51                	j	ffffffffc0200d40 <best_fit_insert_block+0x50>

ffffffffc0200dae <best_fit_nr_free_pages>:
}

static size_t
best_fit_nr_free_pages(void) {
    return nr_free;
}
ffffffffc0200dae:	00005517          	auipc	a0,0x5
ffffffffc0200db2:	28a56503          	lwu	a0,650(a0) # ffffffffc0206038 <free_area+0x10>
ffffffffc0200db6:	8082                	ret

ffffffffc0200db8 <best_fit_alloc_pages>:
    assert(n > 0);
ffffffffc0200db8:	c945                	beqz	a0,ffffffffc0200e68 <best_fit_alloc_pages+0xb0>
    if (n > nr_free) {
ffffffffc0200dba:	00005597          	auipc	a1,0x5
ffffffffc0200dbe:	26e58593          	addi	a1,a1,622 # ffffffffc0206028 <free_area>
ffffffffc0200dc2:	0105e783          	lwu	a5,16(a1)
ffffffffc0200dc6:	862a                	mv	a2,a0
ffffffffc0200dc8:	08a7ee63          	bltu	a5,a0,ffffffffc0200e64 <best_fit_alloc_pages+0xac>
    return listelm->next;
ffffffffc0200dcc:	659c                	ld	a5,8(a1)
    struct Page *best = NULL;
ffffffffc0200dce:	4501                	li	a0,0
    for (list_entry_t *le = list_next(&free_list); le != &free_list;
ffffffffc0200dd0:	08b78963          	beq	a5,a1,ffffffffc0200e62 <best_fit_alloc_pages+0xaa>
        if (p->property >= n &&
ffffffffc0200dd4:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200dd8:	02071693          	slli	a3,a4,0x20
ffffffffc0200ddc:	9281                	srli	a3,a3,0x20
ffffffffc0200dde:	00c6eb63          	bltu	a3,a2,ffffffffc0200df4 <best_fit_alloc_pages+0x3c>
ffffffffc0200de2:	c509                	beqz	a0,ffffffffc0200dec <best_fit_alloc_pages+0x34>
            (best == NULL || p->property < best->property)) {
ffffffffc0200de4:	01052803          	lw	a6,16(a0)
ffffffffc0200de8:	01077663          	bgeu	a4,a6,ffffffffc0200df4 <best_fit_alloc_pages+0x3c>
        struct Page *p = le2page(le, page_link);
ffffffffc0200dec:	fe878513          	addi	a0,a5,-24
            if (p->property == n) {
ffffffffc0200df0:	00c68663          	beq	a3,a2,ffffffffc0200dfc <best_fit_alloc_pages+0x44>
ffffffffc0200df4:	679c                	ld	a5,8(a5)
    for (list_entry_t *le = list_next(&free_list); le != &free_list;
ffffffffc0200df6:	fcb79fe3          	bne	a5,a1,ffffffffc0200dd4 <best_fit_alloc_pages+0x1c>
    if (best == NULL) {
ffffffffc0200dfa:	c525                	beqz	a0,ffffffffc0200e62 <best_fit_alloc_pages+0xaa>
    __list_del(listelm->prev, listelm->next);
ffffffffc0200dfc:	02053803          	ld	a6,32(a0)
    return listelm->prev;
ffffffffc0200e00:	6d18                	ld	a4,24(a0)
    size_t block_size = best->property;
ffffffffc0200e02:	4914                	lw	a3,16(a0)
    list_del_init(&best->page_link);
ffffffffc0200e04:	01850793          	addi	a5,a0,24
    prev->next = next;
ffffffffc0200e08:	01073423          	sd	a6,8(a4)
    next->prev = prev;
ffffffffc0200e0c:	00e83023          	sd	a4,0(a6)
    elm->prev = elm->next = elm;
ffffffffc0200e10:	f11c                	sd	a5,32(a0)
ffffffffc0200e12:	ed1c                	sd	a5,24(a0)
    size_t block_size = best->property;
ffffffffc0200e14:	02069793          	slli	a5,a3,0x20
ffffffffc0200e18:	9381                	srli	a5,a5,0x20
        remainder->property = block_size - n;
ffffffffc0200e1a:	0006081b          	sext.w	a6,a2
    if (block_size > n) {
ffffffffc0200e1e:	02f67663          	bgeu	a2,a5,ffffffffc0200e4a <best_fit_alloc_pages+0x92>
        struct Page *remainder = best + n;
ffffffffc0200e22:	00261793          	slli	a5,a2,0x2
ffffffffc0200e26:	97b2                	add	a5,a5,a2
ffffffffc0200e28:	078e                	slli	a5,a5,0x3
ffffffffc0200e2a:	97aa                	add	a5,a5,a0
        remainder->property = block_size - n;
ffffffffc0200e2c:	410686bb          	subw	a3,a3,a6
ffffffffc0200e30:	cb94                	sw	a3,16(a5)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc0200e32:	00878613          	addi	a2,a5,8
ffffffffc0200e36:	4689                	li	a3,2
ffffffffc0200e38:	40d6302f          	amoor.d	zero,a3,(a2)
    __list_add(elm, listelm, listelm->next);
ffffffffc0200e3c:	6714                	ld	a3,8(a4)
        list_add_after(prev, &remainder->page_link);
ffffffffc0200e3e:	01878613          	addi	a2,a5,24
    prev->next = next->prev = elm;
ffffffffc0200e42:	e290                	sd	a2,0(a3)
ffffffffc0200e44:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0200e46:	f394                	sd	a3,32(a5)
    elm->prev = prev;
ffffffffc0200e48:	ef98                	sd	a4,24(a5)
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc0200e4a:	57f5                	li	a5,-3
ffffffffc0200e4c:	00850713          	addi	a4,a0,8
ffffffffc0200e50:	60f7302f          	amoand.d	zero,a5,(a4)
    nr_free -= n;
ffffffffc0200e54:	499c                	lw	a5,16(a1)
    best->property = 0;
ffffffffc0200e56:	00052823          	sw	zero,16(a0)
    nr_free -= n;
ffffffffc0200e5a:	410787bb          	subw	a5,a5,a6
ffffffffc0200e5e:	c99c                	sw	a5,16(a1)
    return best;
ffffffffc0200e60:	8082                	ret
}
ffffffffc0200e62:	8082                	ret
        return NULL;
ffffffffc0200e64:	4501                	li	a0,0
ffffffffc0200e66:	8082                	ret
best_fit_alloc_pages(size_t n) {
ffffffffc0200e68:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc0200e6a:	00002697          	auipc	a3,0x2
ffffffffc0200e6e:	a2e68693          	addi	a3,a3,-1490 # ffffffffc0202898 <commands+0x768>
ffffffffc0200e72:	00002617          	auipc	a2,0x2
ffffffffc0200e76:	a2e60613          	addi	a2,a2,-1490 # ffffffffc02028a0 <commands+0x770>
ffffffffc0200e7a:	04600593          	li	a1,70
ffffffffc0200e7e:	00002517          	auipc	a0,0x2
ffffffffc0200e82:	a3a50513          	addi	a0,a0,-1478 # ffffffffc02028b8 <commands+0x788>
best_fit_alloc_pages(size_t n) {
ffffffffc0200e86:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0200e88:	d4aff0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0200e8c <best_fit_check>:
}

// LAB2: below code is used to check the best fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
best_fit_check(void) {
ffffffffc0200e8c:	715d                	addi	sp,sp,-80
ffffffffc0200e8e:	e0a2                	sd	s0,64(sp)
    return listelm->next;
ffffffffc0200e90:	00005417          	auipc	s0,0x5
ffffffffc0200e94:	19840413          	addi	s0,s0,408 # ffffffffc0206028 <free_area>
ffffffffc0200e98:	641c                	ld	a5,8(s0)
ffffffffc0200e9a:	e486                	sd	ra,72(sp)
ffffffffc0200e9c:	fc26                	sd	s1,56(sp)
ffffffffc0200e9e:	f84a                	sd	s2,48(sp)
ffffffffc0200ea0:	f44e                	sd	s3,40(sp)
ffffffffc0200ea2:	f052                	sd	s4,32(sp)
ffffffffc0200ea4:	ec56                	sd	s5,24(sp)
ffffffffc0200ea6:	e85a                	sd	s6,16(sp)
ffffffffc0200ea8:	e45e                	sd	s7,8(sp)
ffffffffc0200eaa:	e062                	sd	s8,0(sp)
    int score = 0 ,sumscore = 6;
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200eac:	26878b63          	beq	a5,s0,ffffffffc0201122 <best_fit_check+0x296>
    int count = 0, total = 0;
ffffffffc0200eb0:	4481                	li	s1,0
ffffffffc0200eb2:	4901                	li	s2,0
 * test_bit - Determine whether a bit is set
 * @nr:     the bit to test
 * @addr:   the address to count from
 * */
static inline bool test_bit(int nr, volatile void *addr) {
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc0200eb4:	ff07b703          	ld	a4,-16(a5)
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc0200eb8:	8b09                	andi	a4,a4,2
ffffffffc0200eba:	26070863          	beqz	a4,ffffffffc020112a <best_fit_check+0x29e>
        count ++, total += p->property;
ffffffffc0200ebe:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200ec2:	679c                	ld	a5,8(a5)
ffffffffc0200ec4:	2905                	addiw	s2,s2,1
ffffffffc0200ec6:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200ec8:	fe8796e3          	bne	a5,s0,ffffffffc0200eb4 <best_fit_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc0200ecc:	89a6                	mv	s3,s1
ffffffffc0200ece:	039000ef          	jal	ra,ffffffffc0201706 <nr_free_pages>
ffffffffc0200ed2:	33351c63          	bne	a0,s3,ffffffffc020120a <best_fit_check+0x37e>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200ed6:	4505                	li	a0,1
ffffffffc0200ed8:	7b0000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200edc:	8a2a                	mv	s4,a0
ffffffffc0200ede:	36050663          	beqz	a0,ffffffffc020124a <best_fit_check+0x3be>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200ee2:	4505                	li	a0,1
ffffffffc0200ee4:	7a4000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200ee8:	89aa                	mv	s3,a0
ffffffffc0200eea:	34050063          	beqz	a0,ffffffffc020122a <best_fit_check+0x39e>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200eee:	4505                	li	a0,1
ffffffffc0200ef0:	798000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200ef4:	8aaa                	mv	s5,a0
ffffffffc0200ef6:	2c050a63          	beqz	a0,ffffffffc02011ca <best_fit_check+0x33e>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200efa:	253a0863          	beq	s4,s3,ffffffffc020114a <best_fit_check+0x2be>
ffffffffc0200efe:	24aa0663          	beq	s4,a0,ffffffffc020114a <best_fit_check+0x2be>
ffffffffc0200f02:	24a98463          	beq	s3,a0,ffffffffc020114a <best_fit_check+0x2be>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200f06:	000a2783          	lw	a5,0(s4)
ffffffffc0200f0a:	26079063          	bnez	a5,ffffffffc020116a <best_fit_check+0x2de>
ffffffffc0200f0e:	0009a783          	lw	a5,0(s3)
ffffffffc0200f12:	24079c63          	bnez	a5,ffffffffc020116a <best_fit_check+0x2de>
ffffffffc0200f16:	411c                	lw	a5,0(a0)
ffffffffc0200f18:	24079963          	bnez	a5,ffffffffc020116a <best_fit_check+0x2de>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200f1c:	00005797          	auipc	a5,0x5
ffffffffc0200f20:	5547b783          	ld	a5,1364(a5) # ffffffffc0206470 <pages>
ffffffffc0200f24:	40fa0733          	sub	a4,s4,a5
ffffffffc0200f28:	870d                	srai	a4,a4,0x3
ffffffffc0200f2a:	00002597          	auipc	a1,0x2
ffffffffc0200f2e:	0865b583          	ld	a1,134(a1) # ffffffffc0202fb0 <error_string+0x38>
ffffffffc0200f32:	02b70733          	mul	a4,a4,a1
ffffffffc0200f36:	00002617          	auipc	a2,0x2
ffffffffc0200f3a:	08263603          	ld	a2,130(a2) # ffffffffc0202fb8 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200f3e:	00005697          	auipc	a3,0x5
ffffffffc0200f42:	52a6b683          	ld	a3,1322(a3) # ffffffffc0206468 <npage>
ffffffffc0200f46:	06b2                	slli	a3,a3,0xc
ffffffffc0200f48:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc0200f4a:	0732                	slli	a4,a4,0xc
ffffffffc0200f4c:	22d77f63          	bgeu	a4,a3,ffffffffc020118a <best_fit_check+0x2fe>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200f50:	40f98733          	sub	a4,s3,a5
ffffffffc0200f54:	870d                	srai	a4,a4,0x3
ffffffffc0200f56:	02b70733          	mul	a4,a4,a1
ffffffffc0200f5a:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200f5c:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200f5e:	3ed77663          	bgeu	a4,a3,ffffffffc020134a <best_fit_check+0x4be>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200f62:	40f507b3          	sub	a5,a0,a5
ffffffffc0200f66:	878d                	srai	a5,a5,0x3
ffffffffc0200f68:	02b787b3          	mul	a5,a5,a1
ffffffffc0200f6c:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200f6e:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200f70:	3ad7fd63          	bgeu	a5,a3,ffffffffc020132a <best_fit_check+0x49e>
    assert(alloc_page() == NULL);
ffffffffc0200f74:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200f76:	00043c03          	ld	s8,0(s0)
ffffffffc0200f7a:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc0200f7e:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200f82:	e400                	sd	s0,8(s0)
ffffffffc0200f84:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc0200f86:	00005797          	auipc	a5,0x5
ffffffffc0200f8a:	0a07a923          	sw	zero,178(a5) # ffffffffc0206038 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200f8e:	6fa000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200f92:	36051c63          	bnez	a0,ffffffffc020130a <best_fit_check+0x47e>
    free_page(p0);
ffffffffc0200f96:	4585                	li	a1,1
ffffffffc0200f98:	8552                	mv	a0,s4
ffffffffc0200f9a:	72c000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    free_page(p1);
ffffffffc0200f9e:	4585                	li	a1,1
ffffffffc0200fa0:	854e                	mv	a0,s3
ffffffffc0200fa2:	724000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    free_page(p2);
ffffffffc0200fa6:	4585                	li	a1,1
ffffffffc0200fa8:	8556                	mv	a0,s5
ffffffffc0200faa:	71c000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    assert(nr_free == 3);
ffffffffc0200fae:	4818                	lw	a4,16(s0)
ffffffffc0200fb0:	478d                	li	a5,3
ffffffffc0200fb2:	32f71c63          	bne	a4,a5,ffffffffc02012ea <best_fit_check+0x45e>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200fb6:	4505                	li	a0,1
ffffffffc0200fb8:	6d0000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200fbc:	89aa                	mv	s3,a0
ffffffffc0200fbe:	30050663          	beqz	a0,ffffffffc02012ca <best_fit_check+0x43e>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200fc2:	4505                	li	a0,1
ffffffffc0200fc4:	6c4000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200fc8:	8aaa                	mv	s5,a0
ffffffffc0200fca:	2e050063          	beqz	a0,ffffffffc02012aa <best_fit_check+0x41e>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200fce:	4505                	li	a0,1
ffffffffc0200fd0:	6b8000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200fd4:	8a2a                	mv	s4,a0
ffffffffc0200fd6:	2a050a63          	beqz	a0,ffffffffc020128a <best_fit_check+0x3fe>
    assert(alloc_page() == NULL);
ffffffffc0200fda:	4505                	li	a0,1
ffffffffc0200fdc:	6ac000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200fe0:	28051563          	bnez	a0,ffffffffc020126a <best_fit_check+0x3de>
    free_page(p0);
ffffffffc0200fe4:	4585                	li	a1,1
ffffffffc0200fe6:	854e                	mv	a0,s3
ffffffffc0200fe8:	6de000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200fec:	641c                	ld	a5,8(s0)
ffffffffc0200fee:	1a878e63          	beq	a5,s0,ffffffffc02011aa <best_fit_check+0x31e>
    assert((p = alloc_page()) == p0);
ffffffffc0200ff2:	4505                	li	a0,1
ffffffffc0200ff4:	694000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0200ff8:	52a99963          	bne	s3,a0,ffffffffc020152a <best_fit_check+0x69e>
    assert(alloc_page() == NULL);
ffffffffc0200ffc:	4505                	li	a0,1
ffffffffc0200ffe:	68a000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0201002:	50051463          	bnez	a0,ffffffffc020150a <best_fit_check+0x67e>
    assert(nr_free == 0);
ffffffffc0201006:	481c                	lw	a5,16(s0)
ffffffffc0201008:	4e079163          	bnez	a5,ffffffffc02014ea <best_fit_check+0x65e>
    free_page(p);
ffffffffc020100c:	854e                	mv	a0,s3
ffffffffc020100e:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0201010:	01843023          	sd	s8,0(s0)
ffffffffc0201014:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0201018:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc020101c:	6aa000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    free_page(p1);
ffffffffc0201020:	4585                	li	a1,1
ffffffffc0201022:	8556                	mv	a0,s5
ffffffffc0201024:	6a2000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    free_page(p2);
ffffffffc0201028:	4585                	li	a1,1
ffffffffc020102a:	8552                	mv	a0,s4
ffffffffc020102c:	69a000ef          	jal	ra,ffffffffc02016c6 <free_pages>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0201030:	4515                	li	a0,5
ffffffffc0201032:	656000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0201036:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0201038:	48050963          	beqz	a0,ffffffffc02014ca <best_fit_check+0x63e>
ffffffffc020103c:	651c                	ld	a5,8(a0)
ffffffffc020103e:	8385                	srli	a5,a5,0x1
    assert(!PageProperty(p0));
ffffffffc0201040:	8b85                	andi	a5,a5,1
ffffffffc0201042:	46079463          	bnez	a5,ffffffffc02014aa <best_fit_check+0x61e>
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0201046:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0201048:	00043a83          	ld	s5,0(s0)
ffffffffc020104c:	00843a03          	ld	s4,8(s0)
ffffffffc0201050:	e000                	sd	s0,0(s0)
ffffffffc0201052:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0201054:	634000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0201058:	42051963          	bnez	a0,ffffffffc020148a <best_fit_check+0x5fe>
    #endif
    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    // * - - * -
    free_pages(p0 + 1, 2);
ffffffffc020105c:	4589                	li	a1,2
ffffffffc020105e:	02898513          	addi	a0,s3,40
    unsigned int nr_free_store = nr_free;
ffffffffc0201062:	01042b03          	lw	s6,16(s0)
    free_pages(p0 + 4, 1);
ffffffffc0201066:	0a098c13          	addi	s8,s3,160
    nr_free = 0;
ffffffffc020106a:	00005797          	auipc	a5,0x5
ffffffffc020106e:	fc07a723          	sw	zero,-50(a5) # ffffffffc0206038 <free_area+0x10>
    free_pages(p0 + 1, 2);
ffffffffc0201072:	654000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    free_pages(p0 + 4, 1);
ffffffffc0201076:	8562                	mv	a0,s8
ffffffffc0201078:	4585                	li	a1,1
ffffffffc020107a:	64c000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc020107e:	4511                	li	a0,4
ffffffffc0201080:	608000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc0201084:	3e051363          	bnez	a0,ffffffffc020146a <best_fit_check+0x5de>
ffffffffc0201088:	0309b783          	ld	a5,48(s3)
ffffffffc020108c:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc020108e:	8b85                	andi	a5,a5,1
ffffffffc0201090:	3a078d63          	beqz	a5,ffffffffc020144a <best_fit_check+0x5be>
ffffffffc0201094:	0389a703          	lw	a4,56(s3)
ffffffffc0201098:	4789                	li	a5,2
ffffffffc020109a:	3af71863          	bne	a4,a5,ffffffffc020144a <best_fit_check+0x5be>
    // * - - * *
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc020109e:	4505                	li	a0,1
ffffffffc02010a0:	5e8000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc02010a4:	8baa                	mv	s7,a0
ffffffffc02010a6:	38050263          	beqz	a0,ffffffffc020142a <best_fit_check+0x59e>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc02010aa:	4509                	li	a0,2
ffffffffc02010ac:	5dc000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc02010b0:	34050d63          	beqz	a0,ffffffffc020140a <best_fit_check+0x57e>
    assert(p0 + 4 == p1);
ffffffffc02010b4:	337c1b63          	bne	s8,s7,ffffffffc02013ea <best_fit_check+0x55e>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    p2 = p0 + 1;
    free_pages(p0, 5);
ffffffffc02010b8:	854e                	mv	a0,s3
ffffffffc02010ba:	4595                	li	a1,5
ffffffffc02010bc:	60a000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02010c0:	4515                	li	a0,5
ffffffffc02010c2:	5c6000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc02010c6:	89aa                	mv	s3,a0
ffffffffc02010c8:	30050163          	beqz	a0,ffffffffc02013ca <best_fit_check+0x53e>
    assert(alloc_page() == NULL);
ffffffffc02010cc:	4505                	li	a0,1
ffffffffc02010ce:	5ba000ef          	jal	ra,ffffffffc0201688 <alloc_pages>
ffffffffc02010d2:	2c051c63          	bnez	a0,ffffffffc02013aa <best_fit_check+0x51e>

    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
    assert(nr_free == 0);
ffffffffc02010d6:	481c                	lw	a5,16(s0)
ffffffffc02010d8:	2a079963          	bnez	a5,ffffffffc020138a <best_fit_check+0x4fe>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc02010dc:	4595                	li	a1,5
ffffffffc02010de:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc02010e0:	01642823          	sw	s6,16(s0)
    free_list = free_list_store;
ffffffffc02010e4:	01543023          	sd	s5,0(s0)
ffffffffc02010e8:	01443423          	sd	s4,8(s0)
    free_pages(p0, 5);
ffffffffc02010ec:	5da000ef          	jal	ra,ffffffffc02016c6 <free_pages>
    return listelm->next;
ffffffffc02010f0:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc02010f2:	00878963          	beq	a5,s0,ffffffffc0201104 <best_fit_check+0x278>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc02010f6:	ff87a703          	lw	a4,-8(a5)
ffffffffc02010fa:	679c                	ld	a5,8(a5)
ffffffffc02010fc:	397d                	addiw	s2,s2,-1
ffffffffc02010fe:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0201100:	fe879be3          	bne	a5,s0,ffffffffc02010f6 <best_fit_check+0x26a>
    }
    assert(count == 0);
ffffffffc0201104:	26091363          	bnez	s2,ffffffffc020136a <best_fit_check+0x4de>
    assert(total == 0);
ffffffffc0201108:	e0ed                	bnez	s1,ffffffffc02011ea <best_fit_check+0x35e>
    #ifdef ucore_test
    score += 1;
    cprintf("grading: %d / %d points\n",score, sumscore);
    #endif
}
ffffffffc020110a:	60a6                	ld	ra,72(sp)
ffffffffc020110c:	6406                	ld	s0,64(sp)
ffffffffc020110e:	74e2                	ld	s1,56(sp)
ffffffffc0201110:	7942                	ld	s2,48(sp)
ffffffffc0201112:	79a2                	ld	s3,40(sp)
ffffffffc0201114:	7a02                	ld	s4,32(sp)
ffffffffc0201116:	6ae2                	ld	s5,24(sp)
ffffffffc0201118:	6b42                	ld	s6,16(sp)
ffffffffc020111a:	6ba2                	ld	s7,8(sp)
ffffffffc020111c:	6c02                	ld	s8,0(sp)
ffffffffc020111e:	6161                	addi	sp,sp,80
ffffffffc0201120:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0201122:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0201124:	4481                	li	s1,0
ffffffffc0201126:	4901                	li	s2,0
ffffffffc0201128:	b35d                	j	ffffffffc0200ece <best_fit_check+0x42>
        assert(PageProperty(p));
ffffffffc020112a:	00001697          	auipc	a3,0x1
ffffffffc020112e:	7a668693          	addi	a3,a3,1958 # ffffffffc02028d0 <commands+0x7a0>
ffffffffc0201132:	00001617          	auipc	a2,0x1
ffffffffc0201136:	76e60613          	addi	a2,a2,1902 # ffffffffc02028a0 <commands+0x770>
ffffffffc020113a:	0c400593          	li	a1,196
ffffffffc020113e:	00001517          	auipc	a0,0x1
ffffffffc0201142:	77a50513          	addi	a0,a0,1914 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201146:	a8cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020114a:	00002697          	auipc	a3,0x2
ffffffffc020114e:	81668693          	addi	a3,a3,-2026 # ffffffffc0202960 <commands+0x830>
ffffffffc0201152:	00001617          	auipc	a2,0x1
ffffffffc0201156:	74e60613          	addi	a2,a2,1870 # ffffffffc02028a0 <commands+0x770>
ffffffffc020115a:	09000593          	li	a1,144
ffffffffc020115e:	00001517          	auipc	a0,0x1
ffffffffc0201162:	75a50513          	addi	a0,a0,1882 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201166:	a6cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc020116a:	00002697          	auipc	a3,0x2
ffffffffc020116e:	81e68693          	addi	a3,a3,-2018 # ffffffffc0202988 <commands+0x858>
ffffffffc0201172:	00001617          	auipc	a2,0x1
ffffffffc0201176:	72e60613          	addi	a2,a2,1838 # ffffffffc02028a0 <commands+0x770>
ffffffffc020117a:	09100593          	li	a1,145
ffffffffc020117e:	00001517          	auipc	a0,0x1
ffffffffc0201182:	73a50513          	addi	a0,a0,1850 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201186:	a4cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc020118a:	00002697          	auipc	a3,0x2
ffffffffc020118e:	83e68693          	addi	a3,a3,-1986 # ffffffffc02029c8 <commands+0x898>
ffffffffc0201192:	00001617          	auipc	a2,0x1
ffffffffc0201196:	70e60613          	addi	a2,a2,1806 # ffffffffc02028a0 <commands+0x770>
ffffffffc020119a:	09300593          	li	a1,147
ffffffffc020119e:	00001517          	auipc	a0,0x1
ffffffffc02011a2:	71a50513          	addi	a0,a0,1818 # ffffffffc02028b8 <commands+0x788>
ffffffffc02011a6:	a2cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc02011aa:	00002697          	auipc	a3,0x2
ffffffffc02011ae:	8a668693          	addi	a3,a3,-1882 # ffffffffc0202a50 <commands+0x920>
ffffffffc02011b2:	00001617          	auipc	a2,0x1
ffffffffc02011b6:	6ee60613          	addi	a2,a2,1774 # ffffffffc02028a0 <commands+0x770>
ffffffffc02011ba:	0ac00593          	li	a1,172
ffffffffc02011be:	00001517          	auipc	a0,0x1
ffffffffc02011c2:	6fa50513          	addi	a0,a0,1786 # ffffffffc02028b8 <commands+0x788>
ffffffffc02011c6:	a0cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc02011ca:	00001697          	auipc	a3,0x1
ffffffffc02011ce:	77668693          	addi	a3,a3,1910 # ffffffffc0202940 <commands+0x810>
ffffffffc02011d2:	00001617          	auipc	a2,0x1
ffffffffc02011d6:	6ce60613          	addi	a2,a2,1742 # ffffffffc02028a0 <commands+0x770>
ffffffffc02011da:	08e00593          	li	a1,142
ffffffffc02011de:	00001517          	auipc	a0,0x1
ffffffffc02011e2:	6da50513          	addi	a0,a0,1754 # ffffffffc02028b8 <commands+0x788>
ffffffffc02011e6:	9ecff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(total == 0);
ffffffffc02011ea:	00002697          	auipc	a3,0x2
ffffffffc02011ee:	99668693          	addi	a3,a3,-1642 # ffffffffc0202b80 <commands+0xa50>
ffffffffc02011f2:	00001617          	auipc	a2,0x1
ffffffffc02011f6:	6ae60613          	addi	a2,a2,1710 # ffffffffc02028a0 <commands+0x770>
ffffffffc02011fa:	10600593          	li	a1,262
ffffffffc02011fe:	00001517          	auipc	a0,0x1
ffffffffc0201202:	6ba50513          	addi	a0,a0,1722 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201206:	9ccff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(total == nr_free_pages());
ffffffffc020120a:	00001697          	auipc	a3,0x1
ffffffffc020120e:	6d668693          	addi	a3,a3,1750 # ffffffffc02028e0 <commands+0x7b0>
ffffffffc0201212:	00001617          	auipc	a2,0x1
ffffffffc0201216:	68e60613          	addi	a2,a2,1678 # ffffffffc02028a0 <commands+0x770>
ffffffffc020121a:	0c700593          	li	a1,199
ffffffffc020121e:	00001517          	auipc	a0,0x1
ffffffffc0201222:	69a50513          	addi	a0,a0,1690 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201226:	9acff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc020122a:	00001697          	auipc	a3,0x1
ffffffffc020122e:	6f668693          	addi	a3,a3,1782 # ffffffffc0202920 <commands+0x7f0>
ffffffffc0201232:	00001617          	auipc	a2,0x1
ffffffffc0201236:	66e60613          	addi	a2,a2,1646 # ffffffffc02028a0 <commands+0x770>
ffffffffc020123a:	08d00593          	li	a1,141
ffffffffc020123e:	00001517          	auipc	a0,0x1
ffffffffc0201242:	67a50513          	addi	a0,a0,1658 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201246:	98cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc020124a:	00001697          	auipc	a3,0x1
ffffffffc020124e:	6b668693          	addi	a3,a3,1718 # ffffffffc0202900 <commands+0x7d0>
ffffffffc0201252:	00001617          	auipc	a2,0x1
ffffffffc0201256:	64e60613          	addi	a2,a2,1614 # ffffffffc02028a0 <commands+0x770>
ffffffffc020125a:	08c00593          	li	a1,140
ffffffffc020125e:	00001517          	auipc	a0,0x1
ffffffffc0201262:	65a50513          	addi	a0,a0,1626 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201266:	96cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020126a:	00001697          	auipc	a3,0x1
ffffffffc020126e:	7be68693          	addi	a3,a3,1982 # ffffffffc0202a28 <commands+0x8f8>
ffffffffc0201272:	00001617          	auipc	a2,0x1
ffffffffc0201276:	62e60613          	addi	a2,a2,1582 # ffffffffc02028a0 <commands+0x770>
ffffffffc020127a:	0a900593          	li	a1,169
ffffffffc020127e:	00001517          	auipc	a0,0x1
ffffffffc0201282:	63a50513          	addi	a0,a0,1594 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201286:	94cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020128a:	00001697          	auipc	a3,0x1
ffffffffc020128e:	6b668693          	addi	a3,a3,1718 # ffffffffc0202940 <commands+0x810>
ffffffffc0201292:	00001617          	auipc	a2,0x1
ffffffffc0201296:	60e60613          	addi	a2,a2,1550 # ffffffffc02028a0 <commands+0x770>
ffffffffc020129a:	0a700593          	li	a1,167
ffffffffc020129e:	00001517          	auipc	a0,0x1
ffffffffc02012a2:	61a50513          	addi	a0,a0,1562 # ffffffffc02028b8 <commands+0x788>
ffffffffc02012a6:	92cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02012aa:	00001697          	auipc	a3,0x1
ffffffffc02012ae:	67668693          	addi	a3,a3,1654 # ffffffffc0202920 <commands+0x7f0>
ffffffffc02012b2:	00001617          	auipc	a2,0x1
ffffffffc02012b6:	5ee60613          	addi	a2,a2,1518 # ffffffffc02028a0 <commands+0x770>
ffffffffc02012ba:	0a600593          	li	a1,166
ffffffffc02012be:	00001517          	auipc	a0,0x1
ffffffffc02012c2:	5fa50513          	addi	a0,a0,1530 # ffffffffc02028b8 <commands+0x788>
ffffffffc02012c6:	90cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02012ca:	00001697          	auipc	a3,0x1
ffffffffc02012ce:	63668693          	addi	a3,a3,1590 # ffffffffc0202900 <commands+0x7d0>
ffffffffc02012d2:	00001617          	auipc	a2,0x1
ffffffffc02012d6:	5ce60613          	addi	a2,a2,1486 # ffffffffc02028a0 <commands+0x770>
ffffffffc02012da:	0a500593          	li	a1,165
ffffffffc02012de:	00001517          	auipc	a0,0x1
ffffffffc02012e2:	5da50513          	addi	a0,a0,1498 # ffffffffc02028b8 <commands+0x788>
ffffffffc02012e6:	8ecff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 3);
ffffffffc02012ea:	00001697          	auipc	a3,0x1
ffffffffc02012ee:	75668693          	addi	a3,a3,1878 # ffffffffc0202a40 <commands+0x910>
ffffffffc02012f2:	00001617          	auipc	a2,0x1
ffffffffc02012f6:	5ae60613          	addi	a2,a2,1454 # ffffffffc02028a0 <commands+0x770>
ffffffffc02012fa:	0a300593          	li	a1,163
ffffffffc02012fe:	00001517          	auipc	a0,0x1
ffffffffc0201302:	5ba50513          	addi	a0,a0,1466 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201306:	8ccff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020130a:	00001697          	auipc	a3,0x1
ffffffffc020130e:	71e68693          	addi	a3,a3,1822 # ffffffffc0202a28 <commands+0x8f8>
ffffffffc0201312:	00001617          	auipc	a2,0x1
ffffffffc0201316:	58e60613          	addi	a2,a2,1422 # ffffffffc02028a0 <commands+0x770>
ffffffffc020131a:	09e00593          	li	a1,158
ffffffffc020131e:	00001517          	auipc	a0,0x1
ffffffffc0201322:	59a50513          	addi	a0,a0,1434 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201326:	8acff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc020132a:	00001697          	auipc	a3,0x1
ffffffffc020132e:	6de68693          	addi	a3,a3,1758 # ffffffffc0202a08 <commands+0x8d8>
ffffffffc0201332:	00001617          	auipc	a2,0x1
ffffffffc0201336:	56e60613          	addi	a2,a2,1390 # ffffffffc02028a0 <commands+0x770>
ffffffffc020133a:	09500593          	li	a1,149
ffffffffc020133e:	00001517          	auipc	a0,0x1
ffffffffc0201342:	57a50513          	addi	a0,a0,1402 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201346:	88cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc020134a:	00001697          	auipc	a3,0x1
ffffffffc020134e:	69e68693          	addi	a3,a3,1694 # ffffffffc02029e8 <commands+0x8b8>
ffffffffc0201352:	00001617          	auipc	a2,0x1
ffffffffc0201356:	54e60613          	addi	a2,a2,1358 # ffffffffc02028a0 <commands+0x770>
ffffffffc020135a:	09400593          	li	a1,148
ffffffffc020135e:	00001517          	auipc	a0,0x1
ffffffffc0201362:	55a50513          	addi	a0,a0,1370 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201366:	86cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(count == 0);
ffffffffc020136a:	00002697          	auipc	a3,0x2
ffffffffc020136e:	80668693          	addi	a3,a3,-2042 # ffffffffc0202b70 <commands+0xa40>
ffffffffc0201372:	00001617          	auipc	a2,0x1
ffffffffc0201376:	52e60613          	addi	a2,a2,1326 # ffffffffc02028a0 <commands+0x770>
ffffffffc020137a:	10500593          	li	a1,261
ffffffffc020137e:	00001517          	auipc	a0,0x1
ffffffffc0201382:	53a50513          	addi	a0,a0,1338 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201386:	84cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 0);
ffffffffc020138a:	00001697          	auipc	a3,0x1
ffffffffc020138e:	6fe68693          	addi	a3,a3,1790 # ffffffffc0202a88 <commands+0x958>
ffffffffc0201392:	00001617          	auipc	a2,0x1
ffffffffc0201396:	50e60613          	addi	a2,a2,1294 # ffffffffc02028a0 <commands+0x770>
ffffffffc020139a:	0fa00593          	li	a1,250
ffffffffc020139e:	00001517          	auipc	a0,0x1
ffffffffc02013a2:	51a50513          	addi	a0,a0,1306 # ffffffffc02028b8 <commands+0x788>
ffffffffc02013a6:	82cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc02013aa:	00001697          	auipc	a3,0x1
ffffffffc02013ae:	67e68693          	addi	a3,a3,1662 # ffffffffc0202a28 <commands+0x8f8>
ffffffffc02013b2:	00001617          	auipc	a2,0x1
ffffffffc02013b6:	4ee60613          	addi	a2,a2,1262 # ffffffffc02028a0 <commands+0x770>
ffffffffc02013ba:	0f400593          	li	a1,244
ffffffffc02013be:	00001517          	auipc	a0,0x1
ffffffffc02013c2:	4fa50513          	addi	a0,a0,1274 # ffffffffc02028b8 <commands+0x788>
ffffffffc02013c6:	80cff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc02013ca:	00001697          	auipc	a3,0x1
ffffffffc02013ce:	78668693          	addi	a3,a3,1926 # ffffffffc0202b50 <commands+0xa20>
ffffffffc02013d2:	00001617          	auipc	a2,0x1
ffffffffc02013d6:	4ce60613          	addi	a2,a2,1230 # ffffffffc02028a0 <commands+0x770>
ffffffffc02013da:	0f300593          	li	a1,243
ffffffffc02013de:	00001517          	auipc	a0,0x1
ffffffffc02013e2:	4da50513          	addi	a0,a0,1242 # ffffffffc02028b8 <commands+0x788>
ffffffffc02013e6:	fedfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 + 4 == p1);
ffffffffc02013ea:	00001697          	auipc	a3,0x1
ffffffffc02013ee:	75668693          	addi	a3,a3,1878 # ffffffffc0202b40 <commands+0xa10>
ffffffffc02013f2:	00001617          	auipc	a2,0x1
ffffffffc02013f6:	4ae60613          	addi	a2,a2,1198 # ffffffffc02028a0 <commands+0x770>
ffffffffc02013fa:	0eb00593          	li	a1,235
ffffffffc02013fe:	00001517          	auipc	a0,0x1
ffffffffc0201402:	4ba50513          	addi	a0,a0,1210 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201406:	fcdfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_pages(2) != NULL);      // best fit feature
ffffffffc020140a:	00001697          	auipc	a3,0x1
ffffffffc020140e:	71e68693          	addi	a3,a3,1822 # ffffffffc0202b28 <commands+0x9f8>
ffffffffc0201412:	00001617          	auipc	a2,0x1
ffffffffc0201416:	48e60613          	addi	a2,a2,1166 # ffffffffc02028a0 <commands+0x770>
ffffffffc020141a:	0ea00593          	li	a1,234
ffffffffc020141e:	00001517          	auipc	a0,0x1
ffffffffc0201422:	49a50513          	addi	a0,a0,1178 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201426:	fadfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc020142a:	00001697          	auipc	a3,0x1
ffffffffc020142e:	6de68693          	addi	a3,a3,1758 # ffffffffc0202b08 <commands+0x9d8>
ffffffffc0201432:	00001617          	auipc	a2,0x1
ffffffffc0201436:	46e60613          	addi	a2,a2,1134 # ffffffffc02028a0 <commands+0x770>
ffffffffc020143a:	0e900593          	li	a1,233
ffffffffc020143e:	00001517          	auipc	a0,0x1
ffffffffc0201442:	47a50513          	addi	a0,a0,1146 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201446:	f8dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(PageProperty(p0 + 1) && p0[1].property == 2);
ffffffffc020144a:	00001697          	auipc	a3,0x1
ffffffffc020144e:	68e68693          	addi	a3,a3,1678 # ffffffffc0202ad8 <commands+0x9a8>
ffffffffc0201452:	00001617          	auipc	a2,0x1
ffffffffc0201456:	44e60613          	addi	a2,a2,1102 # ffffffffc02028a0 <commands+0x770>
ffffffffc020145a:	0e700593          	li	a1,231
ffffffffc020145e:	00001517          	auipc	a0,0x1
ffffffffc0201462:	45a50513          	addi	a0,a0,1114 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201466:	f6dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc020146a:	00001697          	auipc	a3,0x1
ffffffffc020146e:	65668693          	addi	a3,a3,1622 # ffffffffc0202ac0 <commands+0x990>
ffffffffc0201472:	00001617          	auipc	a2,0x1
ffffffffc0201476:	42e60613          	addi	a2,a2,1070 # ffffffffc02028a0 <commands+0x770>
ffffffffc020147a:	0e600593          	li	a1,230
ffffffffc020147e:	00001517          	auipc	a0,0x1
ffffffffc0201482:	43a50513          	addi	a0,a0,1082 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201486:	f4dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020148a:	00001697          	auipc	a3,0x1
ffffffffc020148e:	59e68693          	addi	a3,a3,1438 # ffffffffc0202a28 <commands+0x8f8>
ffffffffc0201492:	00001617          	auipc	a2,0x1
ffffffffc0201496:	40e60613          	addi	a2,a2,1038 # ffffffffc02028a0 <commands+0x770>
ffffffffc020149a:	0da00593          	li	a1,218
ffffffffc020149e:	00001517          	auipc	a0,0x1
ffffffffc02014a2:	41a50513          	addi	a0,a0,1050 # ffffffffc02028b8 <commands+0x788>
ffffffffc02014a6:	f2dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(!PageProperty(p0));
ffffffffc02014aa:	00001697          	auipc	a3,0x1
ffffffffc02014ae:	5fe68693          	addi	a3,a3,1534 # ffffffffc0202aa8 <commands+0x978>
ffffffffc02014b2:	00001617          	auipc	a2,0x1
ffffffffc02014b6:	3ee60613          	addi	a2,a2,1006 # ffffffffc02028a0 <commands+0x770>
ffffffffc02014ba:	0d100593          	li	a1,209
ffffffffc02014be:	00001517          	auipc	a0,0x1
ffffffffc02014c2:	3fa50513          	addi	a0,a0,1018 # ffffffffc02028b8 <commands+0x788>
ffffffffc02014c6:	f0dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 != NULL);
ffffffffc02014ca:	00001697          	auipc	a3,0x1
ffffffffc02014ce:	5ce68693          	addi	a3,a3,1486 # ffffffffc0202a98 <commands+0x968>
ffffffffc02014d2:	00001617          	auipc	a2,0x1
ffffffffc02014d6:	3ce60613          	addi	a2,a2,974 # ffffffffc02028a0 <commands+0x770>
ffffffffc02014da:	0d000593          	li	a1,208
ffffffffc02014de:	00001517          	auipc	a0,0x1
ffffffffc02014e2:	3da50513          	addi	a0,a0,986 # ffffffffc02028b8 <commands+0x788>
ffffffffc02014e6:	eedfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 0);
ffffffffc02014ea:	00001697          	auipc	a3,0x1
ffffffffc02014ee:	59e68693          	addi	a3,a3,1438 # ffffffffc0202a88 <commands+0x958>
ffffffffc02014f2:	00001617          	auipc	a2,0x1
ffffffffc02014f6:	3ae60613          	addi	a2,a2,942 # ffffffffc02028a0 <commands+0x770>
ffffffffc02014fa:	0b200593          	li	a1,178
ffffffffc02014fe:	00001517          	auipc	a0,0x1
ffffffffc0201502:	3ba50513          	addi	a0,a0,954 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201506:	ecdfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020150a:	00001697          	auipc	a3,0x1
ffffffffc020150e:	51e68693          	addi	a3,a3,1310 # ffffffffc0202a28 <commands+0x8f8>
ffffffffc0201512:	00001617          	auipc	a2,0x1
ffffffffc0201516:	38e60613          	addi	a2,a2,910 # ffffffffc02028a0 <commands+0x770>
ffffffffc020151a:	0b000593          	li	a1,176
ffffffffc020151e:	00001517          	auipc	a0,0x1
ffffffffc0201522:	39a50513          	addi	a0,a0,922 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201526:	eadfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc020152a:	00001697          	auipc	a3,0x1
ffffffffc020152e:	53e68693          	addi	a3,a3,1342 # ffffffffc0202a68 <commands+0x938>
ffffffffc0201532:	00001617          	auipc	a2,0x1
ffffffffc0201536:	36e60613          	addi	a2,a2,878 # ffffffffc02028a0 <commands+0x770>
ffffffffc020153a:	0af00593          	li	a1,175
ffffffffc020153e:	00001517          	auipc	a0,0x1
ffffffffc0201542:	37a50513          	addi	a0,a0,890 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201546:	e8dfe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc020154a <best_fit_free_pages>:
best_fit_free_pages(struct Page *base, size_t n) {
ffffffffc020154a:	1141                	addi	sp,sp,-16
ffffffffc020154c:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020154e:	cdbd                	beqz	a1,ffffffffc02015cc <best_fit_free_pages+0x82>
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0201550:	00259693          	slli	a3,a1,0x2
ffffffffc0201554:	96ae                	add	a3,a3,a1
ffffffffc0201556:	068e                	slli	a3,a3,0x3
ffffffffc0201558:	96aa                	add	a3,a3,a0
ffffffffc020155a:	87aa                	mv	a5,a0
ffffffffc020155c:	02a68663          	beq	a3,a0,ffffffffc0201588 <best_fit_free_pages+0x3e>
ffffffffc0201560:	6798                	ld	a4,8(a5)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0201562:	8b05                	andi	a4,a4,1
ffffffffc0201564:	e721                	bnez	a4,ffffffffc02015ac <best_fit_free_pages+0x62>
ffffffffc0201566:	6798                	ld	a4,8(a5)
ffffffffc0201568:	8b09                	andi	a4,a4,2
ffffffffc020156a:	e329                	bnez	a4,ffffffffc02015ac <best_fit_free_pages+0x62>
        p->flags = p->property = 0;
ffffffffc020156c:	01878713          	addi	a4,a5,24
ffffffffc0201570:	0007a823          	sw	zero,16(a5)
ffffffffc0201574:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0201578:	0007a023          	sw	zero,0(a5)
    elm->prev = elm->next = elm;
ffffffffc020157c:	f398                	sd	a4,32(a5)
ffffffffc020157e:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc0201580:	02878793          	addi	a5,a5,40
ffffffffc0201584:	fcf69ee3          	bne	a3,a5,ffffffffc0201560 <best_fit_free_pages+0x16>
    base->property = n;
ffffffffc0201588:	2581                	sext.w	a1,a1
ffffffffc020158a:	c90c                	sw	a1,16(a0)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc020158c:	4789                	li	a5,2
ffffffffc020158e:	00850713          	addi	a4,a0,8
ffffffffc0201592:	40f7302f          	amoor.d	zero,a5,(a4)
    nr_free += n;
ffffffffc0201596:	00005717          	auipc	a4,0x5
ffffffffc020159a:	a9270713          	addi	a4,a4,-1390 # ffffffffc0206028 <free_area>
ffffffffc020159e:	4b1c                	lw	a5,16(a4)
}
ffffffffc02015a0:	60a2                	ld	ra,8(sp)
    nr_free += n;
ffffffffc02015a2:	9dbd                	addw	a1,a1,a5
ffffffffc02015a4:	cb0c                	sw	a1,16(a4)
}
ffffffffc02015a6:	0141                	addi	sp,sp,16
    best_fit_insert_block(base);
ffffffffc02015a8:	f48ff06f          	j	ffffffffc0200cf0 <best_fit_insert_block>
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc02015ac:	00001697          	auipc	a3,0x1
ffffffffc02015b0:	5e468693          	addi	a3,a3,1508 # ffffffffc0202b90 <commands+0xa60>
ffffffffc02015b4:	00001617          	auipc	a2,0x1
ffffffffc02015b8:	2ec60613          	addi	a2,a2,748 # ffffffffc02028a0 <commands+0x770>
ffffffffc02015bc:	06e00593          	li	a1,110
ffffffffc02015c0:	00001517          	auipc	a0,0x1
ffffffffc02015c4:	2f850513          	addi	a0,a0,760 # ffffffffc02028b8 <commands+0x788>
ffffffffc02015c8:	e0bfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(n > 0);
ffffffffc02015cc:	00001697          	auipc	a3,0x1
ffffffffc02015d0:	2cc68693          	addi	a3,a3,716 # ffffffffc0202898 <commands+0x768>
ffffffffc02015d4:	00001617          	auipc	a2,0x1
ffffffffc02015d8:	2cc60613          	addi	a2,a2,716 # ffffffffc02028a0 <commands+0x770>
ffffffffc02015dc:	06c00593          	li	a1,108
ffffffffc02015e0:	00001517          	auipc	a0,0x1
ffffffffc02015e4:	2d850513          	addi	a0,a0,728 # ffffffffc02028b8 <commands+0x788>
ffffffffc02015e8:	debfe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc02015ec <best_fit_init_memmap>:
best_fit_init_memmap(struct Page *base, size_t n) {
ffffffffc02015ec:	1141                	addi	sp,sp,-16
ffffffffc02015ee:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc02015f0:	cda5                	beqz	a1,ffffffffc0201668 <best_fit_init_memmap+0x7c>
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc02015f2:	00259693          	slli	a3,a1,0x2
ffffffffc02015f6:	96ae                	add	a3,a3,a1
ffffffffc02015f8:	068e                	slli	a3,a3,0x3
ffffffffc02015fa:	96aa                	add	a3,a3,a0
ffffffffc02015fc:	87aa                	mv	a5,a0
ffffffffc02015fe:	02a68363          	beq	a3,a0,ffffffffc0201624 <best_fit_init_memmap+0x38>
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc0201602:	6798                	ld	a4,8(a5)
        assert(PageReserved(p));
ffffffffc0201604:	8b05                	andi	a4,a4,1
ffffffffc0201606:	c329                	beqz	a4,ffffffffc0201648 <best_fit_init_memmap+0x5c>
        p->flags = p->property = 0;
ffffffffc0201608:	01878713          	addi	a4,a5,24
ffffffffc020160c:	0007a823          	sw	zero,16(a5)
ffffffffc0201610:	0007b423          	sd	zero,8(a5)
ffffffffc0201614:	0007a023          	sw	zero,0(a5)
ffffffffc0201618:	f398                	sd	a4,32(a5)
ffffffffc020161a:	ef98                	sd	a4,24(a5)
    for (struct Page *p = base; p != base + n; p++) {
ffffffffc020161c:	02878793          	addi	a5,a5,40
ffffffffc0201620:	fef691e3          	bne	a3,a5,ffffffffc0201602 <best_fit_init_memmap+0x16>
    base->property = n;
ffffffffc0201624:	2581                	sext.w	a1,a1
ffffffffc0201626:	c90c                	sw	a1,16(a0)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc0201628:	4789                	li	a5,2
ffffffffc020162a:	00850713          	addi	a4,a0,8
ffffffffc020162e:	40f7302f          	amoor.d	zero,a5,(a4)
    nr_free += n;
ffffffffc0201632:	00005717          	auipc	a4,0x5
ffffffffc0201636:	9f670713          	addi	a4,a4,-1546 # ffffffffc0206028 <free_area>
ffffffffc020163a:	4b1c                	lw	a5,16(a4)
}
ffffffffc020163c:	60a2                	ld	ra,8(sp)
    nr_free += n;
ffffffffc020163e:	9dbd                	addw	a1,a1,a5
ffffffffc0201640:	cb0c                	sw	a1,16(a4)
}
ffffffffc0201642:	0141                	addi	sp,sp,16
    best_fit_insert_block(base);
ffffffffc0201644:	eacff06f          	j	ffffffffc0200cf0 <best_fit_insert_block>
        assert(PageReserved(p));
ffffffffc0201648:	00001697          	auipc	a3,0x1
ffffffffc020164c:	57068693          	addi	a3,a3,1392 # ffffffffc0202bb8 <commands+0xa88>
ffffffffc0201650:	00001617          	auipc	a2,0x1
ffffffffc0201654:	25060613          	addi	a2,a2,592 # ffffffffc02028a0 <commands+0x770>
ffffffffc0201658:	03900593          	li	a1,57
ffffffffc020165c:	00001517          	auipc	a0,0x1
ffffffffc0201660:	25c50513          	addi	a0,a0,604 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201664:	d6ffe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(n > 0);
ffffffffc0201668:	00001697          	auipc	a3,0x1
ffffffffc020166c:	23068693          	addi	a3,a3,560 # ffffffffc0202898 <commands+0x768>
ffffffffc0201670:	00001617          	auipc	a2,0x1
ffffffffc0201674:	23060613          	addi	a2,a2,560 # ffffffffc02028a0 <commands+0x770>
ffffffffc0201678:	03700593          	li	a1,55
ffffffffc020167c:	00001517          	auipc	a0,0x1
ffffffffc0201680:	23c50513          	addi	a0,a0,572 # ffffffffc02028b8 <commands+0x788>
ffffffffc0201684:	d4ffe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0201688 <alloc_pages>:
#include <defs.h>
#include <intr.h>
#include <riscv.h>

static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc0201688:	100027f3          	csrr	a5,sstatus
ffffffffc020168c:	8b89                	andi	a5,a5,2
ffffffffc020168e:	e799                	bnez	a5,ffffffffc020169c <alloc_pages+0x14>
struct Page *alloc_pages(size_t n) {
    struct Page *page = NULL;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        page = pmm_manager->alloc_pages(n);
ffffffffc0201690:	00005797          	auipc	a5,0x5
ffffffffc0201694:	de87b783          	ld	a5,-536(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc0201698:	6f9c                	ld	a5,24(a5)
ffffffffc020169a:	8782                	jr	a5
struct Page *alloc_pages(size_t n) {
ffffffffc020169c:	1141                	addi	sp,sp,-16
ffffffffc020169e:	e406                	sd	ra,8(sp)
ffffffffc02016a0:	e022                	sd	s0,0(sp)
ffffffffc02016a2:	842a                	mv	s0,a0
        intr_disable();
ffffffffc02016a4:	990ff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        page = pmm_manager->alloc_pages(n);
ffffffffc02016a8:	00005797          	auipc	a5,0x5
ffffffffc02016ac:	dd07b783          	ld	a5,-560(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc02016b0:	6f9c                	ld	a5,24(a5)
ffffffffc02016b2:	8522                	mv	a0,s0
ffffffffc02016b4:	9782                	jalr	a5
ffffffffc02016b6:	842a                	mv	s0,a0
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
ffffffffc02016b8:	976ff0ef          	jal	ra,ffffffffc020082e <intr_enable>
    }
    local_intr_restore(intr_flag);
    return page;
}
ffffffffc02016bc:	60a2                	ld	ra,8(sp)
ffffffffc02016be:	8522                	mv	a0,s0
ffffffffc02016c0:	6402                	ld	s0,0(sp)
ffffffffc02016c2:	0141                	addi	sp,sp,16
ffffffffc02016c4:	8082                	ret

ffffffffc02016c6 <free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc02016c6:	100027f3          	csrr	a5,sstatus
ffffffffc02016ca:	8b89                	andi	a5,a5,2
ffffffffc02016cc:	e799                	bnez	a5,ffffffffc02016da <free_pages+0x14>
// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        pmm_manager->free_pages(base, n);
ffffffffc02016ce:	00005797          	auipc	a5,0x5
ffffffffc02016d2:	daa7b783          	ld	a5,-598(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc02016d6:	739c                	ld	a5,32(a5)
ffffffffc02016d8:	8782                	jr	a5
void free_pages(struct Page *base, size_t n) {
ffffffffc02016da:	1101                	addi	sp,sp,-32
ffffffffc02016dc:	ec06                	sd	ra,24(sp)
ffffffffc02016de:	e822                	sd	s0,16(sp)
ffffffffc02016e0:	e426                	sd	s1,8(sp)
ffffffffc02016e2:	842a                	mv	s0,a0
ffffffffc02016e4:	84ae                	mv	s1,a1
        intr_disable();
ffffffffc02016e6:	94eff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        pmm_manager->free_pages(base, n);
ffffffffc02016ea:	00005797          	auipc	a5,0x5
ffffffffc02016ee:	d8e7b783          	ld	a5,-626(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc02016f2:	739c                	ld	a5,32(a5)
ffffffffc02016f4:	85a6                	mv	a1,s1
ffffffffc02016f6:	8522                	mv	a0,s0
ffffffffc02016f8:	9782                	jalr	a5
    }
    local_intr_restore(intr_flag);
}
ffffffffc02016fa:	6442                	ld	s0,16(sp)
ffffffffc02016fc:	60e2                	ld	ra,24(sp)
ffffffffc02016fe:	64a2                	ld	s1,8(sp)
ffffffffc0201700:	6105                	addi	sp,sp,32
        intr_enable();
ffffffffc0201702:	92cff06f          	j	ffffffffc020082e <intr_enable>

ffffffffc0201706 <nr_free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc0201706:	100027f3          	csrr	a5,sstatus
ffffffffc020170a:	8b89                	andi	a5,a5,2
ffffffffc020170c:	e799                	bnez	a5,ffffffffc020171a <nr_free_pages+0x14>
size_t nr_free_pages(void) {
    size_t ret;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        ret = pmm_manager->nr_free_pages();
ffffffffc020170e:	00005797          	auipc	a5,0x5
ffffffffc0201712:	d6a7b783          	ld	a5,-662(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc0201716:	779c                	ld	a5,40(a5)
ffffffffc0201718:	8782                	jr	a5
size_t nr_free_pages(void) {
ffffffffc020171a:	1141                	addi	sp,sp,-16
ffffffffc020171c:	e406                	sd	ra,8(sp)
ffffffffc020171e:	e022                	sd	s0,0(sp)
        intr_disable();
ffffffffc0201720:	914ff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        ret = pmm_manager->nr_free_pages();
ffffffffc0201724:	00005797          	auipc	a5,0x5
ffffffffc0201728:	d547b783          	ld	a5,-684(a5) # ffffffffc0206478 <pmm_manager>
ffffffffc020172c:	779c                	ld	a5,40(a5)
ffffffffc020172e:	9782                	jalr	a5
ffffffffc0201730:	842a                	mv	s0,a0
        intr_enable();
ffffffffc0201732:	8fcff0ef          	jal	ra,ffffffffc020082e <intr_enable>
    }
    local_intr_restore(intr_flag);
    return ret;
}
ffffffffc0201736:	60a2                	ld	ra,8(sp)
ffffffffc0201738:	8522                	mv	a0,s0
ffffffffc020173a:	6402                	ld	s0,0(sp)
ffffffffc020173c:	0141                	addi	sp,sp,16
ffffffffc020173e:	8082                	ret

ffffffffc0201740 <pmm_init>:
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201740:	00001797          	auipc	a5,0x1
ffffffffc0201744:	4a078793          	addi	a5,a5,1184 # ffffffffc0202be0 <best_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201748:	638c                	ld	a1,0(a5)
    cprintf("physical memory map:\n");
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", memory_size, memory_base, memory_base + memory_size);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc020174a:	7179                	addi	sp,sp,-48
ffffffffc020174c:	f022                	sd	s0,32(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020174e:	00001517          	auipc	a0,0x1
ffffffffc0201752:	4ca50513          	addi	a0,a0,1226 # ffffffffc0202c18 <best_fit_pmm_manager+0x38>
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201756:	00005417          	auipc	s0,0x5
ffffffffc020175a:	d2240413          	addi	s0,s0,-734 # ffffffffc0206478 <pmm_manager>
void pmm_init(void) {
ffffffffc020175e:	f406                	sd	ra,40(sp)
ffffffffc0201760:	ec26                	sd	s1,24(sp)
ffffffffc0201762:	e84a                	sd	s2,16(sp)
ffffffffc0201764:	e44e                	sd	s3,8(sp)
ffffffffc0201766:	e052                	sd	s4,0(sp)
    pmm_manager = &best_fit_pmm_manager;
ffffffffc0201768:	e01c                	sd	a5,0(s0)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc020176a:	96ffe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    pmm_manager->init();
ffffffffc020176e:	601c                	ld	a5,0(s0)
ffffffffc0201770:	679c                	ld	a5,8(a5)
ffffffffc0201772:	9782                	jalr	a5
    uint64_t memory_base = get_memory_base();
ffffffffc0201774:	8a6ff0ef          	jal	ra,ffffffffc020081a <get_memory_base>
ffffffffc0201778:	84aa                	mv	s1,a0
    uint64_t memory_size = get_memory_size();
ffffffffc020177a:	8aaff0ef          	jal	ra,ffffffffc0200824 <get_memory_size>
    if (memory_base == 0 || memory_size == 0) {
ffffffffc020177e:	14048363          	beqz	s1,ffffffffc02018c4 <pmm_init+0x184>
ffffffffc0201782:	89aa                	mv	s3,a0
ffffffffc0201784:	14050063          	beqz	a0,ffffffffc02018c4 <pmm_init+0x184>
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc0201788:	00a48a33          	add	s4,s1,a0
ffffffffc020178c:	00006817          	auipc	a6,0x6
ffffffffc0201790:	d1380813          	addi	a6,a6,-749 # ffffffffc020749f <end+0xfff>
ffffffffc0201794:	757d                	lui	a0,0xfffff
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201796:	57f5                	li	a5,-3
ffffffffc0201798:	07fa                	slli	a5,a5,0x1e
ffffffffc020179a:	00005917          	auipc	s2,0x5
ffffffffc020179e:	cf690913          	addi	s2,s2,-778 # ffffffffc0206490 <va_pa_offset>
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc02017a2:	00ca5893          	srli	a7,s4,0xc
ffffffffc02017a6:	00005617          	auipc	a2,0x5
ffffffffc02017aa:	cc260613          	addi	a2,a2,-830 # ffffffffc0206468 <npage>
ffffffffc02017ae:	00a87833          	and	a6,a6,a0
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc02017b2:	00005317          	auipc	t1,0x5
ffffffffc02017b6:	cbe30313          	addi	t1,t1,-834 # ffffffffc0206470 <pages>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc02017ba:	00f93023          	sd	a5,0(s2)
    npage = (memory_base + memory_size) / PGSIZE;
ffffffffc02017be:	01163023          	sd	a7,0(a2)
    pages = (struct Page *)ROUNDUP((void *)end, PGSIZE);
ffffffffc02017c2:	01033023          	sd	a6,0(t1)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02017c6:	000807b7          	lui	a5,0x80
ffffffffc02017ca:	02f88a63          	beq	a7,a5,ffffffffc02017fe <pmm_init+0xbe>
ffffffffc02017ce:	4701                	li	a4,0
ffffffffc02017d0:	4781                	li	a5,0
ffffffffc02017d2:	4e85                	li	t4,1
ffffffffc02017d4:	fff80e37          	lui	t3,0xfff80
ffffffffc02017d8:	a019                	j	ffffffffc02017de <pmm_init+0x9e>
        SetPageReserved(pages + i);
ffffffffc02017da:	00033803          	ld	a6,0(t1)
ffffffffc02017de:	983a                	add	a6,a6,a4
ffffffffc02017e0:	00880693          	addi	a3,a6,8
ffffffffc02017e4:	41d6b02f          	amoor.d	zero,t4,(a3)
    for (size_t i = 0; i < npage - nbase; i++) {
ffffffffc02017e8:	00063883          	ld	a7,0(a2)
ffffffffc02017ec:	0785                	addi	a5,a5,1
ffffffffc02017ee:	02870713          	addi	a4,a4,40
ffffffffc02017f2:	01c88833          	add	a6,a7,t3
ffffffffc02017f6:	ff07e2e3          	bltu	a5,a6,ffffffffc02017da <pmm_init+0x9a>
    uintptr_t freemem = PADDR((uintptr_t)pages + (npage - nbase) * sizeof(struct Page));
ffffffffc02017fa:	00033803          	ld	a6,0(t1)
ffffffffc02017fe:	00289713          	slli	a4,a7,0x2
ffffffffc0201802:	9746                	add	a4,a4,a7
ffffffffc0201804:	fec007b7          	lui	a5,0xfec00
ffffffffc0201808:	97c2                	add	a5,a5,a6
ffffffffc020180a:	070e                	slli	a4,a4,0x3
ffffffffc020180c:	973e                	add	a4,a4,a5
ffffffffc020180e:	c02007b7          	lui	a5,0xc0200
ffffffffc0201812:	0cf76563          	bltu	a4,a5,ffffffffc02018dc <pmm_init+0x19c>
    freemem = ROUNDUP(freemem, PGSIZE);
ffffffffc0201816:	00093683          	ld	a3,0(s2)
ffffffffc020181a:	6785                	lui	a5,0x1
ffffffffc020181c:	17fd                	addi	a5,a5,-1
ffffffffc020181e:	8f95                	sub	a5,a5,a3
ffffffffc0201820:	75fd                	lui	a1,0xfffff
ffffffffc0201822:	97ba                	add	a5,a5,a4
ffffffffc0201824:	8fed                	and	a5,a5,a1
    uintptr_t mem_end = ROUNDDOWN(memory_base + memory_size, PGSIZE);
ffffffffc0201826:	00ba75b3          	and	a1,s4,a1
    if (freemem < mem_end) {
ffffffffc020182a:	06b7eb63          	bltu	a5,a1,ffffffffc02018a0 <pmm_init+0x160>
    cprintf("physical memory map:\n");
ffffffffc020182e:	00001517          	auipc	a0,0x1
ffffffffc0201832:	49250513          	addi	a0,a0,1170 # ffffffffc0202cc0 <best_fit_pmm_manager+0xe0>
ffffffffc0201836:	8a3fe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  memory: 0x%016lx, [0x%016lx, 0x%016lx].\n", memory_size, memory_base, memory_base + memory_size);
ffffffffc020183a:	85ce                	mv	a1,s3
ffffffffc020183c:	86d2                	mv	a3,s4
ffffffffc020183e:	8626                	mv	a2,s1
ffffffffc0201840:	00001517          	auipc	a0,0x1
ffffffffc0201844:	49850513          	addi	a0,a0,1176 # ffffffffc0202cd8 <best_fit_pmm_manager+0xf8>
ffffffffc0201848:	891fe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc020184c:	601c                	ld	a5,0(s0)
ffffffffc020184e:	7b9c                	ld	a5,48(a5)
ffffffffc0201850:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0201852:	00001517          	auipc	a0,0x1
ffffffffc0201856:	4b650513          	addi	a0,a0,1206 # ffffffffc0202d08 <best_fit_pmm_manager+0x128>
ffffffffc020185a:	87ffe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc020185e:	00003597          	auipc	a1,0x3
ffffffffc0201862:	7a258593          	addi	a1,a1,1954 # ffffffffc0205000 <boot_page_table_sv39>
ffffffffc0201866:	00005797          	auipc	a5,0x5
ffffffffc020186a:	c2b7b123          	sd	a1,-990(a5) # ffffffffc0206488 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc020186e:	c02007b7          	lui	a5,0xc0200
ffffffffc0201872:	08f5e263          	bltu	a1,a5,ffffffffc02018f6 <pmm_init+0x1b6>
ffffffffc0201876:	00093603          	ld	a2,0(s2)
}
ffffffffc020187a:	7402                	ld	s0,32(sp)
ffffffffc020187c:	70a2                	ld	ra,40(sp)
ffffffffc020187e:	64e2                	ld	s1,24(sp)
ffffffffc0201880:	6942                	ld	s2,16(sp)
ffffffffc0201882:	69a2                	ld	s3,8(sp)
ffffffffc0201884:	6a02                	ld	s4,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201886:	40c58633          	sub	a2,a1,a2
ffffffffc020188a:	00005797          	auipc	a5,0x5
ffffffffc020188e:	bec7bb23          	sd	a2,-1034(a5) # ffffffffc0206480 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201892:	00001517          	auipc	a0,0x1
ffffffffc0201896:	49650513          	addi	a0,a0,1174 # ffffffffc0202d28 <best_fit_pmm_manager+0x148>
}
ffffffffc020189a:	6145                	addi	sp,sp,48
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020189c:	83dfe06f          	j	ffffffffc02000d8 <cprintf>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc02018a0:	00c7d513          	srli	a0,a5,0xc
ffffffffc02018a4:	07157663          	bgeu	a0,a7,ffffffffc0201910 <pmm_init+0x1d0>
    pmm_manager->init_memmap(base, n);
ffffffffc02018a8:	6014                	ld	a3,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc02018aa:	fff80737          	lui	a4,0xfff80
ffffffffc02018ae:	972a                	add	a4,a4,a0
ffffffffc02018b0:	00271513          	slli	a0,a4,0x2
ffffffffc02018b4:	953a                	add	a0,a0,a4
ffffffffc02018b6:	6a98                	ld	a4,16(a3)
        init_memmap(pa2page(freemem), (mem_end - freemem) / PGSIZE);
ffffffffc02018b8:	8d9d                	sub	a1,a1,a5
ffffffffc02018ba:	050e                	slli	a0,a0,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc02018bc:	81b1                	srli	a1,a1,0xc
ffffffffc02018be:	9542                	add	a0,a0,a6
ffffffffc02018c0:	9702                	jalr	a4
}
ffffffffc02018c2:	b7b5                	j	ffffffffc020182e <pmm_init+0xee>
        panic("No physical memory detected by DTB.");
ffffffffc02018c4:	00001617          	auipc	a2,0x1
ffffffffc02018c8:	36c60613          	addi	a2,a2,876 # ffffffffc0202c30 <best_fit_pmm_manager+0x50>
ffffffffc02018cc:	05b00593          	li	a1,91
ffffffffc02018d0:	00001517          	auipc	a0,0x1
ffffffffc02018d4:	38850513          	addi	a0,a0,904 # ffffffffc0202c58 <best_fit_pmm_manager+0x78>
ffffffffc02018d8:	afbfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    uintptr_t freemem = PADDR((uintptr_t)pages + (npage - nbase) * sizeof(struct Page));
ffffffffc02018dc:	86ba                	mv	a3,a4
ffffffffc02018de:	00001617          	auipc	a2,0x1
ffffffffc02018e2:	38a60613          	addi	a2,a2,906 # ffffffffc0202c68 <best_fit_pmm_manager+0x88>
ffffffffc02018e6:	07100593          	li	a1,113
ffffffffc02018ea:	00001517          	auipc	a0,0x1
ffffffffc02018ee:	36e50513          	addi	a0,a0,878 # ffffffffc0202c58 <best_fit_pmm_manager+0x78>
ffffffffc02018f2:	ae1fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02018f6:	86ae                	mv	a3,a1
ffffffffc02018f8:	00001617          	auipc	a2,0x1
ffffffffc02018fc:	37060613          	addi	a2,a2,880 # ffffffffc0202c68 <best_fit_pmm_manager+0x88>
ffffffffc0201900:	09200593          	li	a1,146
ffffffffc0201904:	00001517          	auipc	a0,0x1
ffffffffc0201908:	35450513          	addi	a0,a0,852 # ffffffffc0202c58 <best_fit_pmm_manager+0x78>
ffffffffc020190c:	ac7fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
        panic("pa2page called with invalid pa");
ffffffffc0201910:	00001617          	auipc	a2,0x1
ffffffffc0201914:	38060613          	addi	a2,a2,896 # ffffffffc0202c90 <best_fit_pmm_manager+0xb0>
ffffffffc0201918:	06b00593          	li	a1,107
ffffffffc020191c:	00001517          	auipc	a0,0x1
ffffffffc0201920:	39450513          	addi	a0,a0,916 # ffffffffc0202cb0 <best_fit_pmm_manager+0xd0>
ffffffffc0201924:	aaffe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0201928 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0201928:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020192c:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc020192e:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201932:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201934:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201938:	f022                	sd	s0,32(sp)
ffffffffc020193a:	ec26                	sd	s1,24(sp)
ffffffffc020193c:	e84a                	sd	s2,16(sp)
ffffffffc020193e:	f406                	sd	ra,40(sp)
ffffffffc0201940:	e44e                	sd	s3,8(sp)
ffffffffc0201942:	84aa                	mv	s1,a0
ffffffffc0201944:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0201946:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc020194a:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc020194c:	03067e63          	bgeu	a2,a6,ffffffffc0201988 <printnum+0x60>
ffffffffc0201950:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0201952:	00805763          	blez	s0,ffffffffc0201960 <printnum+0x38>
ffffffffc0201956:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201958:	85ca                	mv	a1,s2
ffffffffc020195a:	854e                	mv	a0,s3
ffffffffc020195c:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc020195e:	fc65                	bnez	s0,ffffffffc0201956 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201960:	1a02                	slli	s4,s4,0x20
ffffffffc0201962:	00001797          	auipc	a5,0x1
ffffffffc0201966:	40678793          	addi	a5,a5,1030 # ffffffffc0202d68 <best_fit_pmm_manager+0x188>
ffffffffc020196a:	020a5a13          	srli	s4,s4,0x20
ffffffffc020196e:	9a3e                	add	s4,s4,a5
}
ffffffffc0201970:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201972:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201976:	70a2                	ld	ra,40(sp)
ffffffffc0201978:	69a2                	ld	s3,8(sp)
ffffffffc020197a:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020197c:	85ca                	mv	a1,s2
ffffffffc020197e:	87a6                	mv	a5,s1
}
ffffffffc0201980:	6942                	ld	s2,16(sp)
ffffffffc0201982:	64e2                	ld	s1,24(sp)
ffffffffc0201984:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201986:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201988:	03065633          	divu	a2,a2,a6
ffffffffc020198c:	8722                	mv	a4,s0
ffffffffc020198e:	f9bff0ef          	jal	ra,ffffffffc0201928 <printnum>
ffffffffc0201992:	b7f9                	j	ffffffffc0201960 <printnum+0x38>

ffffffffc0201994 <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201994:	7119                	addi	sp,sp,-128
ffffffffc0201996:	f4a6                	sd	s1,104(sp)
ffffffffc0201998:	f0ca                	sd	s2,96(sp)
ffffffffc020199a:	ecce                	sd	s3,88(sp)
ffffffffc020199c:	e8d2                	sd	s4,80(sp)
ffffffffc020199e:	e4d6                	sd	s5,72(sp)
ffffffffc02019a0:	e0da                	sd	s6,64(sp)
ffffffffc02019a2:	fc5e                	sd	s7,56(sp)
ffffffffc02019a4:	f06a                	sd	s10,32(sp)
ffffffffc02019a6:	fc86                	sd	ra,120(sp)
ffffffffc02019a8:	f8a2                	sd	s0,112(sp)
ffffffffc02019aa:	f862                	sd	s8,48(sp)
ffffffffc02019ac:	f466                	sd	s9,40(sp)
ffffffffc02019ae:	ec6e                	sd	s11,24(sp)
ffffffffc02019b0:	892a                	mv	s2,a0
ffffffffc02019b2:	84ae                	mv	s1,a1
ffffffffc02019b4:	8d32                	mv	s10,a2
ffffffffc02019b6:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02019b8:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc02019bc:	5b7d                	li	s6,-1
ffffffffc02019be:	00001a97          	auipc	s5,0x1
ffffffffc02019c2:	3dea8a93          	addi	s5,s5,990 # ffffffffc0202d9c <best_fit_pmm_manager+0x1bc>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02019c6:	00001b97          	auipc	s7,0x1
ffffffffc02019ca:	5b2b8b93          	addi	s7,s7,1458 # ffffffffc0202f78 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02019ce:	000d4503          	lbu	a0,0(s10)
ffffffffc02019d2:	001d0413          	addi	s0,s10,1
ffffffffc02019d6:	01350a63          	beq	a0,s3,ffffffffc02019ea <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc02019da:	c121                	beqz	a0,ffffffffc0201a1a <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc02019dc:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02019de:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc02019e0:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02019e2:	fff44503          	lbu	a0,-1(s0)
ffffffffc02019e6:	ff351ae3          	bne	a0,s3,ffffffffc02019da <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02019ea:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc02019ee:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc02019f2:	4c81                	li	s9,0
ffffffffc02019f4:	4881                	li	a7,0
        width = precision = -1;
ffffffffc02019f6:	5c7d                	li	s8,-1
ffffffffc02019f8:	5dfd                	li	s11,-1
ffffffffc02019fa:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc02019fe:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201a00:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201a04:	0ff5f593          	zext.b	a1,a1
ffffffffc0201a08:	00140d13          	addi	s10,s0,1
ffffffffc0201a0c:	04b56263          	bltu	a0,a1,ffffffffc0201a50 <vprintfmt+0xbc>
ffffffffc0201a10:	058a                	slli	a1,a1,0x2
ffffffffc0201a12:	95d6                	add	a1,a1,s5
ffffffffc0201a14:	4194                	lw	a3,0(a1)
ffffffffc0201a16:	96d6                	add	a3,a3,s5
ffffffffc0201a18:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201a1a:	70e6                	ld	ra,120(sp)
ffffffffc0201a1c:	7446                	ld	s0,112(sp)
ffffffffc0201a1e:	74a6                	ld	s1,104(sp)
ffffffffc0201a20:	7906                	ld	s2,96(sp)
ffffffffc0201a22:	69e6                	ld	s3,88(sp)
ffffffffc0201a24:	6a46                	ld	s4,80(sp)
ffffffffc0201a26:	6aa6                	ld	s5,72(sp)
ffffffffc0201a28:	6b06                	ld	s6,64(sp)
ffffffffc0201a2a:	7be2                	ld	s7,56(sp)
ffffffffc0201a2c:	7c42                	ld	s8,48(sp)
ffffffffc0201a2e:	7ca2                	ld	s9,40(sp)
ffffffffc0201a30:	7d02                	ld	s10,32(sp)
ffffffffc0201a32:	6de2                	ld	s11,24(sp)
ffffffffc0201a34:	6109                	addi	sp,sp,128
ffffffffc0201a36:	8082                	ret
            padc = '0';
ffffffffc0201a38:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201a3a:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201a3e:	846a                	mv	s0,s10
ffffffffc0201a40:	00140d13          	addi	s10,s0,1
ffffffffc0201a44:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201a48:	0ff5f593          	zext.b	a1,a1
ffffffffc0201a4c:	fcb572e3          	bgeu	a0,a1,ffffffffc0201a10 <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201a50:	85a6                	mv	a1,s1
ffffffffc0201a52:	02500513          	li	a0,37
ffffffffc0201a56:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201a58:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201a5c:	8d22                	mv	s10,s0
ffffffffc0201a5e:	f73788e3          	beq	a5,s3,ffffffffc02019ce <vprintfmt+0x3a>
ffffffffc0201a62:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0201a66:	1d7d                	addi	s10,s10,-1
ffffffffc0201a68:	ff379de3          	bne	a5,s3,ffffffffc0201a62 <vprintfmt+0xce>
ffffffffc0201a6c:	b78d                	j	ffffffffc02019ce <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201a6e:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201a72:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201a76:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201a78:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201a7c:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201a80:	02d86463          	bltu	a6,a3,ffffffffc0201aa8 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201a84:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201a88:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201a8c:	0186873b          	addw	a4,a3,s8
ffffffffc0201a90:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201a94:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201a96:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201a9a:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201a9c:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201aa0:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201aa4:	fed870e3          	bgeu	a6,a3,ffffffffc0201a84 <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201aa8:	f40ddce3          	bgez	s11,ffffffffc0201a00 <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201aac:	8de2                	mv	s11,s8
ffffffffc0201aae:	5c7d                	li	s8,-1
ffffffffc0201ab0:	bf81                	j	ffffffffc0201a00 <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201ab2:	fffdc693          	not	a3,s11
ffffffffc0201ab6:	96fd                	srai	a3,a3,0x3f
ffffffffc0201ab8:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201abc:	00144603          	lbu	a2,1(s0)
ffffffffc0201ac0:	2d81                	sext.w	s11,s11
ffffffffc0201ac2:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201ac4:	bf35                	j	ffffffffc0201a00 <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201ac6:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201aca:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201ace:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201ad0:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201ad2:	bfd9                	j	ffffffffc0201aa8 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201ad4:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201ad6:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201ada:	01174463          	blt	a4,a7,ffffffffc0201ae2 <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201ade:	1a088e63          	beqz	a7,ffffffffc0201c9a <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201ae2:	000a3603          	ld	a2,0(s4)
ffffffffc0201ae6:	46c1                	li	a3,16
ffffffffc0201ae8:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201aea:	2781                	sext.w	a5,a5
ffffffffc0201aec:	876e                	mv	a4,s11
ffffffffc0201aee:	85a6                	mv	a1,s1
ffffffffc0201af0:	854a                	mv	a0,s2
ffffffffc0201af2:	e37ff0ef          	jal	ra,ffffffffc0201928 <printnum>
            break;
ffffffffc0201af6:	bde1                	j	ffffffffc02019ce <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201af8:	000a2503          	lw	a0,0(s4)
ffffffffc0201afc:	85a6                	mv	a1,s1
ffffffffc0201afe:	0a21                	addi	s4,s4,8
ffffffffc0201b00:	9902                	jalr	s2
            break;
ffffffffc0201b02:	b5f1                	j	ffffffffc02019ce <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201b04:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201b06:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201b0a:	01174463          	blt	a4,a7,ffffffffc0201b12 <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201b0e:	18088163          	beqz	a7,ffffffffc0201c90 <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201b12:	000a3603          	ld	a2,0(s4)
ffffffffc0201b16:	46a9                	li	a3,10
ffffffffc0201b18:	8a2e                	mv	s4,a1
ffffffffc0201b1a:	bfc1                	j	ffffffffc0201aea <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b1c:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201b20:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b22:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201b24:	bdf1                	j	ffffffffc0201a00 <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201b26:	85a6                	mv	a1,s1
ffffffffc0201b28:	02500513          	li	a0,37
ffffffffc0201b2c:	9902                	jalr	s2
            break;
ffffffffc0201b2e:	b545                	j	ffffffffc02019ce <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b30:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201b34:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b36:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201b38:	b5e1                	j	ffffffffc0201a00 <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201b3a:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201b3c:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201b40:	01174463          	blt	a4,a7,ffffffffc0201b48 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201b44:	14088163          	beqz	a7,ffffffffc0201c86 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0201b48:	000a3603          	ld	a2,0(s4)
ffffffffc0201b4c:	46a1                	li	a3,8
ffffffffc0201b4e:	8a2e                	mv	s4,a1
ffffffffc0201b50:	bf69                	j	ffffffffc0201aea <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201b52:	03000513          	li	a0,48
ffffffffc0201b56:	85a6                	mv	a1,s1
ffffffffc0201b58:	e03e                	sd	a5,0(sp)
ffffffffc0201b5a:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201b5c:	85a6                	mv	a1,s1
ffffffffc0201b5e:	07800513          	li	a0,120
ffffffffc0201b62:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201b64:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201b66:	6782                	ld	a5,0(sp)
ffffffffc0201b68:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201b6a:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201b6e:	bfb5                	j	ffffffffc0201aea <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201b70:	000a3403          	ld	s0,0(s4)
ffffffffc0201b74:	008a0713          	addi	a4,s4,8
ffffffffc0201b78:	e03a                	sd	a4,0(sp)
ffffffffc0201b7a:	14040263          	beqz	s0,ffffffffc0201cbe <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201b7e:	0fb05763          	blez	s11,ffffffffc0201c6c <vprintfmt+0x2d8>
ffffffffc0201b82:	02d00693          	li	a3,45
ffffffffc0201b86:	0cd79163          	bne	a5,a3,ffffffffc0201c48 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201b8a:	00044783          	lbu	a5,0(s0)
ffffffffc0201b8e:	0007851b          	sext.w	a0,a5
ffffffffc0201b92:	cf85                	beqz	a5,ffffffffc0201bca <vprintfmt+0x236>
ffffffffc0201b94:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201b98:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201b9c:	000c4563          	bltz	s8,ffffffffc0201ba6 <vprintfmt+0x212>
ffffffffc0201ba0:	3c7d                	addiw	s8,s8,-1
ffffffffc0201ba2:	036c0263          	beq	s8,s6,ffffffffc0201bc6 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201ba6:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201ba8:	0e0c8e63          	beqz	s9,ffffffffc0201ca4 <vprintfmt+0x310>
ffffffffc0201bac:	3781                	addiw	a5,a5,-32
ffffffffc0201bae:	0ef47b63          	bgeu	s0,a5,ffffffffc0201ca4 <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201bb2:	03f00513          	li	a0,63
ffffffffc0201bb6:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201bb8:	000a4783          	lbu	a5,0(s4)
ffffffffc0201bbc:	3dfd                	addiw	s11,s11,-1
ffffffffc0201bbe:	0a05                	addi	s4,s4,1
ffffffffc0201bc0:	0007851b          	sext.w	a0,a5
ffffffffc0201bc4:	ffe1                	bnez	a5,ffffffffc0201b9c <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201bc6:	01b05963          	blez	s11,ffffffffc0201bd8 <vprintfmt+0x244>
ffffffffc0201bca:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201bcc:	85a6                	mv	a1,s1
ffffffffc0201bce:	02000513          	li	a0,32
ffffffffc0201bd2:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201bd4:	fe0d9be3          	bnez	s11,ffffffffc0201bca <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201bd8:	6a02                	ld	s4,0(sp)
ffffffffc0201bda:	bbd5                	j	ffffffffc02019ce <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201bdc:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201bde:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201be2:	01174463          	blt	a4,a7,ffffffffc0201bea <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201be6:	08088d63          	beqz	a7,ffffffffc0201c80 <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201bea:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201bee:	0a044d63          	bltz	s0,ffffffffc0201ca8 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201bf2:	8622                	mv	a2,s0
ffffffffc0201bf4:	8a66                	mv	s4,s9
ffffffffc0201bf6:	46a9                	li	a3,10
ffffffffc0201bf8:	bdcd                	j	ffffffffc0201aea <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201bfa:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201bfe:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201c00:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201c02:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201c06:	8fb5                	xor	a5,a5,a3
ffffffffc0201c08:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201c0c:	02d74163          	blt	a4,a3,ffffffffc0201c2e <vprintfmt+0x29a>
ffffffffc0201c10:	00369793          	slli	a5,a3,0x3
ffffffffc0201c14:	97de                	add	a5,a5,s7
ffffffffc0201c16:	639c                	ld	a5,0(a5)
ffffffffc0201c18:	cb99                	beqz	a5,ffffffffc0201c2e <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201c1a:	86be                	mv	a3,a5
ffffffffc0201c1c:	00001617          	auipc	a2,0x1
ffffffffc0201c20:	17c60613          	addi	a2,a2,380 # ffffffffc0202d98 <best_fit_pmm_manager+0x1b8>
ffffffffc0201c24:	85a6                	mv	a1,s1
ffffffffc0201c26:	854a                	mv	a0,s2
ffffffffc0201c28:	0ce000ef          	jal	ra,ffffffffc0201cf6 <printfmt>
ffffffffc0201c2c:	b34d                	j	ffffffffc02019ce <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201c2e:	00001617          	auipc	a2,0x1
ffffffffc0201c32:	15a60613          	addi	a2,a2,346 # ffffffffc0202d88 <best_fit_pmm_manager+0x1a8>
ffffffffc0201c36:	85a6                	mv	a1,s1
ffffffffc0201c38:	854a                	mv	a0,s2
ffffffffc0201c3a:	0bc000ef          	jal	ra,ffffffffc0201cf6 <printfmt>
ffffffffc0201c3e:	bb41                	j	ffffffffc02019ce <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201c40:	00001417          	auipc	s0,0x1
ffffffffc0201c44:	14040413          	addi	s0,s0,320 # ffffffffc0202d80 <best_fit_pmm_manager+0x1a0>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201c48:	85e2                	mv	a1,s8
ffffffffc0201c4a:	8522                	mv	a0,s0
ffffffffc0201c4c:	e43e                	sd	a5,8(sp)
ffffffffc0201c4e:	200000ef          	jal	ra,ffffffffc0201e4e <strnlen>
ffffffffc0201c52:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201c56:	01b05b63          	blez	s11,ffffffffc0201c6c <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201c5a:	67a2                	ld	a5,8(sp)
ffffffffc0201c5c:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201c60:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201c62:	85a6                	mv	a1,s1
ffffffffc0201c64:	8552                	mv	a0,s4
ffffffffc0201c66:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201c68:	fe0d9ce3          	bnez	s11,ffffffffc0201c60 <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c6c:	00044783          	lbu	a5,0(s0)
ffffffffc0201c70:	00140a13          	addi	s4,s0,1
ffffffffc0201c74:	0007851b          	sext.w	a0,a5
ffffffffc0201c78:	d3a5                	beqz	a5,ffffffffc0201bd8 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201c7a:	05e00413          	li	s0,94
ffffffffc0201c7e:	bf39                	j	ffffffffc0201b9c <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201c80:	000a2403          	lw	s0,0(s4)
ffffffffc0201c84:	b7ad                	j	ffffffffc0201bee <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201c86:	000a6603          	lwu	a2,0(s4)
ffffffffc0201c8a:	46a1                	li	a3,8
ffffffffc0201c8c:	8a2e                	mv	s4,a1
ffffffffc0201c8e:	bdb1                	j	ffffffffc0201aea <vprintfmt+0x156>
ffffffffc0201c90:	000a6603          	lwu	a2,0(s4)
ffffffffc0201c94:	46a9                	li	a3,10
ffffffffc0201c96:	8a2e                	mv	s4,a1
ffffffffc0201c98:	bd89                	j	ffffffffc0201aea <vprintfmt+0x156>
ffffffffc0201c9a:	000a6603          	lwu	a2,0(s4)
ffffffffc0201c9e:	46c1                	li	a3,16
ffffffffc0201ca0:	8a2e                	mv	s4,a1
ffffffffc0201ca2:	b5a1                	j	ffffffffc0201aea <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201ca4:	9902                	jalr	s2
ffffffffc0201ca6:	bf09                	j	ffffffffc0201bb8 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201ca8:	85a6                	mv	a1,s1
ffffffffc0201caa:	02d00513          	li	a0,45
ffffffffc0201cae:	e03e                	sd	a5,0(sp)
ffffffffc0201cb0:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201cb2:	6782                	ld	a5,0(sp)
ffffffffc0201cb4:	8a66                	mv	s4,s9
ffffffffc0201cb6:	40800633          	neg	a2,s0
ffffffffc0201cba:	46a9                	li	a3,10
ffffffffc0201cbc:	b53d                	j	ffffffffc0201aea <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201cbe:	03b05163          	blez	s11,ffffffffc0201ce0 <vprintfmt+0x34c>
ffffffffc0201cc2:	02d00693          	li	a3,45
ffffffffc0201cc6:	f6d79de3          	bne	a5,a3,ffffffffc0201c40 <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201cca:	00001417          	auipc	s0,0x1
ffffffffc0201cce:	0b640413          	addi	s0,s0,182 # ffffffffc0202d80 <best_fit_pmm_manager+0x1a0>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201cd2:	02800793          	li	a5,40
ffffffffc0201cd6:	02800513          	li	a0,40
ffffffffc0201cda:	00140a13          	addi	s4,s0,1
ffffffffc0201cde:	bd6d                	j	ffffffffc0201b98 <vprintfmt+0x204>
ffffffffc0201ce0:	00001a17          	auipc	s4,0x1
ffffffffc0201ce4:	0a1a0a13          	addi	s4,s4,161 # ffffffffc0202d81 <best_fit_pmm_manager+0x1a1>
ffffffffc0201ce8:	02800513          	li	a0,40
ffffffffc0201cec:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201cf0:	05e00413          	li	s0,94
ffffffffc0201cf4:	b565                	j	ffffffffc0201b9c <vprintfmt+0x208>

ffffffffc0201cf6 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201cf6:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201cf8:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201cfc:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201cfe:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201d00:	ec06                	sd	ra,24(sp)
ffffffffc0201d02:	f83a                	sd	a4,48(sp)
ffffffffc0201d04:	fc3e                	sd	a5,56(sp)
ffffffffc0201d06:	e0c2                	sd	a6,64(sp)
ffffffffc0201d08:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201d0a:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201d0c:	c89ff0ef          	jal	ra,ffffffffc0201994 <vprintfmt>
}
ffffffffc0201d10:	60e2                	ld	ra,24(sp)
ffffffffc0201d12:	6161                	addi	sp,sp,80
ffffffffc0201d14:	8082                	ret

ffffffffc0201d16 <readline>:
 * The readline() function returns the text of the line read. If some errors
 * are happened, NULL is returned. The return value is a global variable,
 * thus it should be copied before it is used.
 * */
char *
readline(const char *prompt) {
ffffffffc0201d16:	715d                	addi	sp,sp,-80
ffffffffc0201d18:	e486                	sd	ra,72(sp)
ffffffffc0201d1a:	e0a6                	sd	s1,64(sp)
ffffffffc0201d1c:	fc4a                	sd	s2,56(sp)
ffffffffc0201d1e:	f84e                	sd	s3,48(sp)
ffffffffc0201d20:	f452                	sd	s4,40(sp)
ffffffffc0201d22:	f056                	sd	s5,32(sp)
ffffffffc0201d24:	ec5a                	sd	s6,24(sp)
ffffffffc0201d26:	e85e                	sd	s7,16(sp)
    if (prompt != NULL) {
ffffffffc0201d28:	c901                	beqz	a0,ffffffffc0201d38 <readline+0x22>
ffffffffc0201d2a:	85aa                	mv	a1,a0
        cprintf("%s", prompt);
ffffffffc0201d2c:	00001517          	auipc	a0,0x1
ffffffffc0201d30:	06c50513          	addi	a0,a0,108 # ffffffffc0202d98 <best_fit_pmm_manager+0x1b8>
ffffffffc0201d34:	ba4fe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
readline(const char *prompt) {
ffffffffc0201d38:	4481                	li	s1,0
    while (1) {
        c = getchar();
        if (c < 0) {
            return NULL;
        }
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201d3a:	497d                	li	s2,31
            cputchar(c);
            buf[i ++] = c;
        }
        else if (c == '\b' && i > 0) {
ffffffffc0201d3c:	49a1                	li	s3,8
            cputchar(c);
            i --;
        }
        else if (c == '\n' || c == '\r') {
ffffffffc0201d3e:	4aa9                	li	s5,10
ffffffffc0201d40:	4b35                	li	s6,13
            buf[i ++] = c;
ffffffffc0201d42:	00004b97          	auipc	s7,0x4
ffffffffc0201d46:	2feb8b93          	addi	s7,s7,766 # ffffffffc0206040 <buf>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201d4a:	3fe00a13          	li	s4,1022
        c = getchar();
ffffffffc0201d4e:	c02fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201d52:	00054a63          	bltz	a0,ffffffffc0201d66 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201d56:	00a95a63          	bge	s2,a0,ffffffffc0201d6a <readline+0x54>
ffffffffc0201d5a:	029a5263          	bge	s4,s1,ffffffffc0201d7e <readline+0x68>
        c = getchar();
ffffffffc0201d5e:	bf2fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201d62:	fe055ae3          	bgez	a0,ffffffffc0201d56 <readline+0x40>
            return NULL;
ffffffffc0201d66:	4501                	li	a0,0
ffffffffc0201d68:	a091                	j	ffffffffc0201dac <readline+0x96>
        else if (c == '\b' && i > 0) {
ffffffffc0201d6a:	03351463          	bne	a0,s3,ffffffffc0201d92 <readline+0x7c>
ffffffffc0201d6e:	e8a9                	bnez	s1,ffffffffc0201dc0 <readline+0xaa>
        c = getchar();
ffffffffc0201d70:	be0fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201d74:	fe0549e3          	bltz	a0,ffffffffc0201d66 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201d78:	fea959e3          	bge	s2,a0,ffffffffc0201d6a <readline+0x54>
ffffffffc0201d7c:	4481                	li	s1,0
            cputchar(c);
ffffffffc0201d7e:	e42a                	sd	a0,8(sp)
ffffffffc0201d80:	b8efe0ef          	jal	ra,ffffffffc020010e <cputchar>
            buf[i ++] = c;
ffffffffc0201d84:	6522                	ld	a0,8(sp)
ffffffffc0201d86:	009b87b3          	add	a5,s7,s1
ffffffffc0201d8a:	2485                	addiw	s1,s1,1
ffffffffc0201d8c:	00a78023          	sb	a0,0(a5)
ffffffffc0201d90:	bf7d                	j	ffffffffc0201d4e <readline+0x38>
        else if (c == '\n' || c == '\r') {
ffffffffc0201d92:	01550463          	beq	a0,s5,ffffffffc0201d9a <readline+0x84>
ffffffffc0201d96:	fb651ce3          	bne	a0,s6,ffffffffc0201d4e <readline+0x38>
            cputchar(c);
ffffffffc0201d9a:	b74fe0ef          	jal	ra,ffffffffc020010e <cputchar>
            buf[i] = '\0';
ffffffffc0201d9e:	00004517          	auipc	a0,0x4
ffffffffc0201da2:	2a250513          	addi	a0,a0,674 # ffffffffc0206040 <buf>
ffffffffc0201da6:	94aa                	add	s1,s1,a0
ffffffffc0201da8:	00048023          	sb	zero,0(s1)
            return buf;
        }
    }
}
ffffffffc0201dac:	60a6                	ld	ra,72(sp)
ffffffffc0201dae:	6486                	ld	s1,64(sp)
ffffffffc0201db0:	7962                	ld	s2,56(sp)
ffffffffc0201db2:	79c2                	ld	s3,48(sp)
ffffffffc0201db4:	7a22                	ld	s4,40(sp)
ffffffffc0201db6:	7a82                	ld	s5,32(sp)
ffffffffc0201db8:	6b62                	ld	s6,24(sp)
ffffffffc0201dba:	6bc2                	ld	s7,16(sp)
ffffffffc0201dbc:	6161                	addi	sp,sp,80
ffffffffc0201dbe:	8082                	ret
            cputchar(c);
ffffffffc0201dc0:	4521                	li	a0,8
ffffffffc0201dc2:	b4cfe0ef          	jal	ra,ffffffffc020010e <cputchar>
            i --;
ffffffffc0201dc6:	34fd                	addiw	s1,s1,-1
ffffffffc0201dc8:	b759                	j	ffffffffc0201d4e <readline+0x38>

ffffffffc0201dca <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201dca:	4781                	li	a5,0
ffffffffc0201dcc:	00004717          	auipc	a4,0x4
ffffffffc0201dd0:	24c73703          	ld	a4,588(a4) # ffffffffc0206018 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201dd4:	88ba                	mv	a7,a4
ffffffffc0201dd6:	852a                	mv	a0,a0
ffffffffc0201dd8:	85be                	mv	a1,a5
ffffffffc0201dda:	863e                	mv	a2,a5
ffffffffc0201ddc:	00000073          	ecall
ffffffffc0201de0:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201de2:	8082                	ret

ffffffffc0201de4 <sbi_set_timer>:
    __asm__ volatile (
ffffffffc0201de4:	4781                	li	a5,0
ffffffffc0201de6:	00004717          	auipc	a4,0x4
ffffffffc0201dea:	6b273703          	ld	a4,1714(a4) # ffffffffc0206498 <SBI_SET_TIMER>
ffffffffc0201dee:	88ba                	mv	a7,a4
ffffffffc0201df0:	852a                	mv	a0,a0
ffffffffc0201df2:	85be                	mv	a1,a5
ffffffffc0201df4:	863e                	mv	a2,a5
ffffffffc0201df6:	00000073          	ecall
ffffffffc0201dfa:	87aa                	mv	a5,a0

void sbi_set_timer(unsigned long long stime_value) {
    sbi_call(SBI_SET_TIMER, stime_value, 0, 0);
}
ffffffffc0201dfc:	8082                	ret

ffffffffc0201dfe <sbi_console_getchar>:
    __asm__ volatile (
ffffffffc0201dfe:	4501                	li	a0,0
ffffffffc0201e00:	00004797          	auipc	a5,0x4
ffffffffc0201e04:	2107b783          	ld	a5,528(a5) # ffffffffc0206010 <SBI_CONSOLE_GETCHAR>
ffffffffc0201e08:	88be                	mv	a7,a5
ffffffffc0201e0a:	852a                	mv	a0,a0
ffffffffc0201e0c:	85aa                	mv	a1,a0
ffffffffc0201e0e:	862a                	mv	a2,a0
ffffffffc0201e10:	00000073          	ecall
ffffffffc0201e14:	852a                	mv	a0,a0

int sbi_console_getchar(void) {
    return sbi_call(SBI_CONSOLE_GETCHAR, 0, 0, 0);
}
ffffffffc0201e16:	2501                	sext.w	a0,a0
ffffffffc0201e18:	8082                	ret

ffffffffc0201e1a <sbi_shutdown>:
    __asm__ volatile (
ffffffffc0201e1a:	4781                	li	a5,0
ffffffffc0201e1c:	00004717          	auipc	a4,0x4
ffffffffc0201e20:	20473703          	ld	a4,516(a4) # ffffffffc0206020 <SBI_SHUTDOWN>
ffffffffc0201e24:	88ba                	mv	a7,a4
ffffffffc0201e26:	853e                	mv	a0,a5
ffffffffc0201e28:	85be                	mv	a1,a5
ffffffffc0201e2a:	863e                	mv	a2,a5
ffffffffc0201e2c:	00000073          	ecall
ffffffffc0201e30:	87aa                	mv	a5,a0

void sbi_shutdown(void)
{
	sbi_call(SBI_SHUTDOWN, 0, 0, 0);
ffffffffc0201e32:	8082                	ret

ffffffffc0201e34 <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201e34:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201e38:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201e3a:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201e3c:	cb81                	beqz	a5,ffffffffc0201e4c <strlen+0x18>
        cnt ++;
ffffffffc0201e3e:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201e40:	00a707b3          	add	a5,a4,a0
ffffffffc0201e44:	0007c783          	lbu	a5,0(a5)
ffffffffc0201e48:	fbfd                	bnez	a5,ffffffffc0201e3e <strlen+0xa>
ffffffffc0201e4a:	8082                	ret
    }
    return cnt;
}
ffffffffc0201e4c:	8082                	ret

ffffffffc0201e4e <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201e4e:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201e50:	e589                	bnez	a1,ffffffffc0201e5a <strnlen+0xc>
ffffffffc0201e52:	a811                	j	ffffffffc0201e66 <strnlen+0x18>
        cnt ++;
ffffffffc0201e54:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201e56:	00f58863          	beq	a1,a5,ffffffffc0201e66 <strnlen+0x18>
ffffffffc0201e5a:	00f50733          	add	a4,a0,a5
ffffffffc0201e5e:	00074703          	lbu	a4,0(a4)
ffffffffc0201e62:	fb6d                	bnez	a4,ffffffffc0201e54 <strnlen+0x6>
ffffffffc0201e64:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201e66:	852e                	mv	a0,a1
ffffffffc0201e68:	8082                	ret

ffffffffc0201e6a <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201e6a:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201e6e:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201e72:	cb89                	beqz	a5,ffffffffc0201e84 <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201e74:	0505                	addi	a0,a0,1
ffffffffc0201e76:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201e78:	fee789e3          	beq	a5,a4,ffffffffc0201e6a <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201e7c:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201e80:	9d19                	subw	a0,a0,a4
ffffffffc0201e82:	8082                	ret
ffffffffc0201e84:	4501                	li	a0,0
ffffffffc0201e86:	bfed                	j	ffffffffc0201e80 <strcmp+0x16>

ffffffffc0201e88 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e88:	c20d                	beqz	a2,ffffffffc0201eaa <strncmp+0x22>
ffffffffc0201e8a:	962e                	add	a2,a2,a1
ffffffffc0201e8c:	a031                	j	ffffffffc0201e98 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201e8e:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e90:	00e79a63          	bne	a5,a4,ffffffffc0201ea4 <strncmp+0x1c>
ffffffffc0201e94:	00b60b63          	beq	a2,a1,ffffffffc0201eaa <strncmp+0x22>
ffffffffc0201e98:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201e9c:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201e9e:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201ea2:	f7f5                	bnez	a5,ffffffffc0201e8e <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201ea4:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201ea8:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201eaa:	4501                	li	a0,0
ffffffffc0201eac:	8082                	ret

ffffffffc0201eae <strchr>:
 * The strchr() function returns a pointer to the first occurrence of
 * character in @s. If the value is not found, the function returns 'NULL'.
 * */
char *
strchr(const char *s, char c) {
    while (*s != '\0') {
ffffffffc0201eae:	00054783          	lbu	a5,0(a0)
ffffffffc0201eb2:	c799                	beqz	a5,ffffffffc0201ec0 <strchr+0x12>
        if (*s == c) {
ffffffffc0201eb4:	00f58763          	beq	a1,a5,ffffffffc0201ec2 <strchr+0x14>
    while (*s != '\0') {
ffffffffc0201eb8:	00154783          	lbu	a5,1(a0)
            return (char *)s;
        }
        s ++;
ffffffffc0201ebc:	0505                	addi	a0,a0,1
    while (*s != '\0') {
ffffffffc0201ebe:	fbfd                	bnez	a5,ffffffffc0201eb4 <strchr+0x6>
    }
    return NULL;
ffffffffc0201ec0:	4501                	li	a0,0
}
ffffffffc0201ec2:	8082                	ret

ffffffffc0201ec4 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201ec4:	ca01                	beqz	a2,ffffffffc0201ed4 <memset+0x10>
ffffffffc0201ec6:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201ec8:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201eca:	0785                	addi	a5,a5,1
ffffffffc0201ecc:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201ed0:	fec79de3          	bne	a5,a2,ffffffffc0201eca <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201ed4:	8082                	ret
