/* 用自制 printf 输出，同时验证：
 *   1. 字符串字面量能读（.rodata 在 DMEM）
 *   2. 硬件乘法、软件除法
 *   3. printf 的 %d / %x / %s / %c
 *
 * a、b、d 必须是 volatile，否则 gcc 编译期就把结果算死了，
 * 硬件乘法器和 div.c 都不会被调用。
 */

int  printf_(const char *fmt, ...);
int  getchar_(void);
void putc_(char c);

int main(void)
{
    volatile int a = 6;
    volatile int b = 7;
    volatile int d = 5;

    int p = a * b;           /* 42  硬件 mul */
    int q = p / d;           /* 8   软件 __divsi3 */
    int r = p % d;           /* 2   软件 __modsi3 */
    int c;

    printf_("Hello!\r\n");   /* 字符串字面量 */
    printf_("A=%d\r\n", p);  /* %d */
    printf_("B=%d\r\n", q);
    printf_("C=%d\r\n", r);
    printf_("%x %s%c\r\n", 0xbeef, "ok", '!');   /* %x %s %c */

    /* 等串口发来一个字节，收到后回显 —— 验证 UART 接收通路 */
    c = getchar_();
    printf_("got %c\r\n", c);

    for (;;) { }
}
