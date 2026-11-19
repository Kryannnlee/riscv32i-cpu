/* 链接脚本 —— 决定代码和数据放在哪块内存 */

ENTRY(_start)

MEMORY
{
    /* 和 rtl/imem.sv、rtl/dmem.sv 的容量一一对应，改一处就要改另一处 */
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rw)  : ORIGIN = 0x00001000, LENGTH = 4K
}

SECTIONS
{
    /* .text.start 必须排在最前面，保证 _start 落在地址 0 */
    .text : {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    } > IMEM

    .data : {
        *(.data*)
        *(.sdata*)
    } > DMEM

    .bss : {
        *(.bss*)
        *(.sbss*)
        *(COMMON)
    } > DMEM

    /* 栈顶：DMEM 的末尾。crt0 里 la sp, _stack_top 就是取这个符号 */
    _stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
