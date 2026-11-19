# 启动代码 crt0 —— CPU 复位后执行的第一条指令从这里开始
#
# 为什么必须有它：
#   编译器生成的代码默认"栈已经有人设好了"。而 CPU 一复位 sp = 0，
#   第一条带栈操作的指令就会往地址 0 附近写，把变量区踩坏。
#   所以进 main 之前必须先把 sp 设到内存顶部。

    .section .text.start, "ax"
    .globl _start

_start:
    la      sp, _stack_top      # 栈顶 = DMEM 末尾，栈向下生长
    call    main                # 调用 C 的 main
1:  j       1b                  # main 返回后原地死循环（没有操作系统可以返回）
