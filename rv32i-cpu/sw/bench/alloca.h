#ifndef _ALLOCA_H
#define _ALLOCA_H

/* 标准 <alloca.h> 是 libc 的一部分，我们没有 libc。
 * 但 alloca 本质上是编译器内建（在栈上分配），用 __builtin_alloca 即可。 */
#define alloca(n) __builtin_alloca(n)

#endif
