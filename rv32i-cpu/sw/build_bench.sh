#!/usr/bin/env bash
# 构建 Dhrystone 基准测试，产物覆盖 sw/prog.hex / sw/prog_data.hex
#
# 用法（在 sw/ 目录下）：
#   bash build_bench.sh
#
# 跑完想恢复普通演示程序： bash build.sh
#
# 和 build.sh 的区别：
#   1. 源文件换成 bench/dhrystone*.c，不链接 main.c（main 会冲突）
#   2. -std=gnu89：Dhrystone 2.2 是 K&R 风格的老代码，C99+ 编不过
#   3. -Dprintf=printf_：把 Dhrystone 里的 printf 指向我们自己的实现
#   4. -Ibench：让 <stdio.h> <string.h> <alloca.h> <util.h> 找到 bench/ 里的最小替代
set -euo pipefail
cd "$(dirname "$0")"

CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
OBJDUMP=${OBJDUMP:-riscv64-unknown-elf-objdump}

CFLAGS="-march=rv32im -mno-div -mabi=ilp32 -O2 -nostdlib -nostartfiles -std=gnu89 \
        -T link.ld -Ibench -Dprintf=printf_"

echo "==> 编译 Dhrystone"
$CC $CFLAGS start.S \
    bench/dhrystone.c bench/dhrystone_main.c bench/support.c \
    div.c printf.c -o bench.elf

echo "==> 转指令段"
$OBJCOPY -O binary -j .text bench.elf prog.bin
python3 bin2hex.py prog.bin prog.hex 2048 00000013

echo "==> 转数据段"
$OBJCOPY -O binary -j .rodata -j .data bench.elf prog.data
python3 bin2hex.py prog.data prog_data.hex 4096 00000000

echo "==> 反汇编"
$OBJDUMP -d bench.elf > bench.dis

echo
echo "== 产物 =="
ls -l bench.elf prog.hex prog_data.hex
echo
echo "代码大小: $(stat -c%s prog.bin) 字节 / IMEM 8KB"
echo "数据大小: $(stat -c%s prog.data) 字节 / DMEM 8KB"
