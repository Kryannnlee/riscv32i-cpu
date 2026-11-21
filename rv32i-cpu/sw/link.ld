/* 链接脚本 —— 决定代码和数据放在哪块内存 */

ENTRY(_start)

MEMORY
{
    /* 和 rtl/imem.sv、rtl/dmem.sv 的容量一一对应，改一处就要改另一处：
     *
     *   0x0000 ~ 0x1FFF   IMEM   8KB（2048 字，索引 addr[12:2]）
     *   0x4000 ~ 0x7FFF   DMEM  16KB（4096 字，索引 addr[13:2]）
     *   0x8000 ~          MMIO（UART + 周期计数器）
     *
     * 基址必须让"index = addr[高位:2]"正好落在数组范围内：
     *   8KB  = 2^13 字节 → 基址低 13 位必须为 0（0x0000 或 0x2000 ...）
     *   16KB = 2^14 字节 → 基址低 14 位必须为 0（0x0000 或 0x4000 ...）
     * 所以 DMEM 放在 0x4000，而不是紧接着 IMEM。
     *
     * 为什么 16KB：Dhrystone 的 Arr_2_Glob[50][50]（int）一个人就占 10KB。
     */
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    DMEM (rw)  : ORIGIN = 0x00004000, LENGTH = 16K
}

SECTIONS
{
    /* .text.start 必须排在最前面，保证 _start 落在地址 0 */
    .text : {
        KEEP(*(.text.start))
        *(.text*)
    } > IMEM

    /* 常量（含字符串字面量）放数据内存，不能留在 IMEM！
     *
     * 原因：CPU 是哈佛结构，lw/lb 只连 dmem（0x1000 起），
     * 永远读不到 IMEM（0x0 起）。字符串留在 .rodata@IMEM 的话，
     * 程序读到的是垃圾（见 cases/case-23）。
     *
     * .rodata 必须排在 DMEM 的最前面：build.sh 用 objcopy 把
     * 「从 0x1000 开始」的这段字节抽成 prog_data.hex，
     * 顺序错了数据就会错位。
     */
    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > DMEM

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
