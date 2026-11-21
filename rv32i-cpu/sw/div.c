/* libgcc 风格的 32 位乘除法辅助函数
 *
 * 为什么需要它们：
 *   编译用 -march=rv32im -mno-div。
 *   - rv32im  打开硬件乘法 -> gcc 直接生成 mul/mulh 指令（ALU 里已实现）
 *   - -mno-div 关闭硬件除法 -> gcc 生成对 __divsi3 等的调用，由这里提供
 *
 * 为什么除法不做硬件：
 *   实测 32 位组合除法器最长路径 82.6ns（WNS -62.6ns @ 20ns），
 *   50MHz 跑不动。要做只能改成多周期，那是另一个工程。
 *
 * 名字必须是这几个：libgcc 约定，gcc 生成的就是这些符号。
 */

/* ---------------- 无符号除法：移一位、比一次、减一次 ---------------- */
unsigned int __udivsi3(unsigned int n, unsigned int d)
{
    unsigned long long r = 0;
    unsigned int q = 0;
    int i;

    if (d == 0)
        return 0xFFFFFFFFu;          /* RISC-V 规定：除零返回 -1 */

    for (i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1u);   /* 把被除数的下一位挪进余数 */
        if (r >= (unsigned long long)d) {
            r -= d;
            q |= (1u << i);              /* 够减，这一位上商 1 */
        }
    }
    return q;
}

unsigned int __umodsi3(unsigned int n, unsigned int d)
{
    unsigned long long r = 0;
    int i;

    if (d == 0)
        return n;                     /* RISC-V 规定：取模除零返回被除数 */

    for (i = 31; i >= 0; i--) {
        r = (r << 1) | ((n >> i) & 1u);
        if (r >= (unsigned long long)d)
            r -= d;
    }
    return (unsigned int)r;
}

/* ---------------- 有符号：取绝对值算完再补符号 ---------------- */
int __divsi3(int a, int b)
{
    unsigned int ua, ub, uq;

    if (b == 0)
        return -1;                                /* 除零 -> -1 */
    if (a == (int)0x80000000 && b == -1)
        return (int)0x80000000;                   /* 唯一溢出：INT_MIN / -1 */

    ua = (a < 0) ? -(unsigned int)a : (unsigned int)a;
    ub = (b < 0) ? -(unsigned int)b : (unsigned int)b;
    uq = __udivsi3(ua, ub);

    return ((a < 0) != (b < 0)) ? -(int)uq : (int)uq;
}

int __modsi3(int a, int b)
{
    unsigned int ua, ub, uq, ur;

    if (b == 0)
        return a;                                 /* 除零 -> 被除数 */
    if (a == (int)0x80000000 && b == -1)
        return 0;                                 /* 商的符号处理完，余数为 0 */

    ua = (a < 0) ? -(unsigned int)a : (unsigned int)a;
    ub = (b < 0) ? -(unsigned int)b : (unsigned int)b;
    uq = __udivsi3(ua, ub);
    ur = ua - uq * ub;                            /* 余数在这里算（用硬件 mul） */

    return (a < 0) ? -(int)ur : (int)ur;          /* 余数的符号跟着被除数 */
}
