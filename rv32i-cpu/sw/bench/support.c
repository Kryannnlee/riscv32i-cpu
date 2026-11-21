/* Dhrystone 移植所需的最小 libc 替代
 *
 * Dhrystone 用到：strcpy / strcmp / memcpy / malloc / setStats
 * 我们一个 libc 都没有，只能自己写。
 */

void setStats(int enable)
{
    (void)enable;          /* riscv-tests 框架用的，我们没有这套东西 */
}

/* ---------------- 字符串 ---------------- */
char *strcpy(char *dst, const char *src)
{
    char *r = dst;
    while ((*dst++ = *src++) != 0) { }
    return r;
}

int strcmp(const char *a, const char *b)
{
    while (*a && (*a == *b)) {
        a++;
        b++;
    }
    return (int)(unsigned char)*a - (int)(unsigned char)*b;
}

void *memcpy(void *dst, const void *src, unsigned int n)
{
    unsigned char       *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

/* ---------------- 分配器 ----------------
 * 极简 bump 分配器：只往后挪指针，free 什么都不做。
 * Dhrystone 基本不 malloc（它用 alloca，那是编译器内建、走栈），
 * 这里只是把符号补上，避免链接失败。
 */
#define HEAP_SIZE 2048
static unsigned char heap[HEAP_SIZE];
static unsigned int  heap_used = 0;

void *malloc(unsigned int n)
{
    void *p;

    n = (n + 3u) & ~3u;                    /* 4 字节对齐 */
    if (heap_used + n > HEAP_SIZE) return (void *)0;

    p = (void *)&heap[heap_used];
    heap_used += n;
    return p;
}

void free(void *p)
{
    (void)p;                               /* bump 分配器不回收 */
}
