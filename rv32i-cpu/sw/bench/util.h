#ifndef _UTIL_H
#define _UTIL_H

/* riscv-tests 的 util.h 里 setStats 是往它们自己的测试框架上报统计的。
 * 我们没有那套框架，只需要一个空实现。 */

int  printf_(const char *fmt, ...);   /* 构建时用 -Dprintf=printf_ 把 printf 指过来 */
void setStats(int enable);

#endif
