#ifndef _STDIO_H
#define _STDIO_H

/* 最小 stdio.h。
 * 构建时加 -Dprintf=printf_，所以下面这个声明会变成 printf_ 的声明，
 * 实际链接到 sw/printf.c 里的实现。 */
int printf(const char *fmt, ...);

#endif
