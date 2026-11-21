/* 最小 printf：走 UART，不依赖 libc
 *
 * 支持：%d %u %x %c %s %%
 * 不支持：宽度/精度修饰（如 %05d）、浮点、%p
 *
 * 关于 va_list：它来自 gcc 自带的 stdarg.h（编译器头文件，不是 libc），
 * 所以 -nostdlib 下也能用。
 *
 * 注意不要把这个函数命名成 printf —— gcc 会对同名函数做内建优化检查，
 * 参数约定对不上会报警告。用 printf_ 明确是我们自己的实现。
 */

#include <stdarg.h>

// MMIO 地址（和 rtl/cpu_pipe.sv 的译码一致；IMEM 0x0~0x1FFF，DMEM 0x4000~0x7FFF）
#define UART ((volatile unsigned char *)0x8000)

void putc_(char c)
{
    while (*UART) { }        /* 等上一帧发完 */
    *UART = c;
}

void puts_(const char *s)
{
    while (*s)
        putc_(*s++);
}

/* 接收一个字节（阻塞等待）
 *   0x8004 读 = valid（1 表示有新数据）
 *   0x8008 读 = 数据，读的同时硬件清掉 valid（相当于"取走"）
 */
int getchar_(void)
{
    volatile unsigned char *status = (volatile unsigned char *)0x8004;
    volatile unsigned char *data   = (volatile unsigned char *)0x8008;

    while (*status == 0) { }        /* 空转等对方发 */
    return (int)(*data);
}

/* 十进制/十六进制输出，无符号 */
static void putnum_(unsigned int v, unsigned int base)
{
    char buf[12];
    int n = 0;
    const char *digits = "0123456789abcdef";   /* 字符串常量，从 .rodata 读 */

    if (v == 0) {
        putc_('0');
        return;
    }
    while (v > 0) {
        buf[n++] = digits[v % base];
        v /= base;
    }
    while (n > 0)
        putc_(buf[--n]);
}

int printf_(const char *fmt, ...)
{
    va_list ap;
    int count = 0;

    va_start(ap, fmt);
    for (; *fmt; fmt++) {
        if (*fmt != '%') {
            putc_(*fmt);
            count++;
            continue;
        }

        fmt++;
        /* 跳过长度修饰符。RV32 ILP32 下 int/long/指针都是 32 位，
         * 所以 %ld / %lu / %lx 直接按 32 位处理即可。 */
        if (*fmt == 'l' || *fmt == 'z' || *fmt == 'h')
            fmt++;

        switch (*fmt) {
        case 'd': {
            int v = va_arg(ap, int);
            unsigned int u;
            if (v < 0) {
                putc_('-');
                count++;
                u = -(unsigned int)v;   /* 先转无符号再取负，INT_MIN 也安全 */
            } else {
                u = (unsigned int)v;
            }
            putnum_(u, 10);
            break;
        }
        case 'u':
            putnum_(va_arg(ap, unsigned int), 10);
            break;
        case 'x':
            putnum_(va_arg(ap, unsigned int), 16);
            break;
        case 'c':
            putc_((char)va_arg(ap, int));
            break;
        case 's':
            puts_(va_arg(ap, const char *));
            break;
        case '%':
            putc_('%');
            break;
        case '\0':
            fmt--;                  /* 末尾的孤零零一个 %，别越界 */
            break;
        default:
            putc_('%');             /* 不认识的格式符原样输出 */
            putc_(*fmt);
            break;
        }
        count++;
    }
    va_end(ap);
    return count;
}
