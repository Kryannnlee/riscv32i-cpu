/* 第一个真正有输出的 C 程序：算 1+2+...+10，把结果从串口打出来
 *
 * 不能用字符串字面量！
 *   字符串会被编译器放进 .rodata，而按 link.ld 它在 IMEM 里。
 *   我们的 lw 只走 dmem，读 imem 的地址会拿到别的东西。
 *   所以这里一个字符一个字符地发。
 *
 * MMIO 约定（和 rtl/cpu_pipe.sv 里的译码一致）：
 *   0x3000  写 = 串口发一个字节
 *   0x3000  读 = 1 表示上一帧还没发完，0 表示空闲
 */

#define UART ((volatile unsigned char *)0x3000)

static void putc_(char c)
{
    while (*UART) { }        /* 等上一帧发完 */
    *UART = c;
}

int main(void)
{
    unsigned int sum = 0;
    int i;
    int n = 0;
    char buf[4];

    for (i = 1; i <= 10; i++)
        sum += i;

    putc_('S');
    putc_('U');
    putc_('M');
    putc_('=');

    /* 十进制打印，没有 libc 的 printf */
    if (sum == 0) {
        buf[n++] = '0';
    }
    while (sum > 0) {
        buf[n++] = (char)('0' + (sum % 10));
        sum /= 10;
    }
    while (n > 0)
        putc_(buf[--n]);

    putc_('\r');
    putc_('\n');

    for (;;) { }
}
