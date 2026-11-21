#!/usr/bin/env bash
# 编译 C 程序 -> ELF -> 裸二进制 -> $readmemh 用的 hex
# 在 VM 里执行：  bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
OBJDUMP=${OBJDUMP:-riscv64-unknown-elf-objdump}

# -march=rv32im  开硬件乘法（ALU 里已实现 mul/mulh/mulhu/mulhsu）
# -mno-div       关硬件除法，让 gcc 调用 div.c 里的 __divsi3 等
#                 （组合除法器实测 82.6ns 一条，50MHz 跑不动）
CFLAGS="-march=rv32im -mno-div -mabi=ilp32 -O2 -nostdlib -nostartfiles -T link.ld"

echo "==> 编译"
$CC $CFLAGS start.S main.c div.c printf.c -o prog.elf

echo "==> 转指令段（只取 .text，不然会把中间 4KB 空隙也带上）"
$OBJCOPY -O binary -j .text prog.elf prog.bin

echo "==> 转指令 hex（其余补 NOP）"
python3 bin2hex.py prog.bin prog.hex 2048 00000013

echo "==> 转数据段（.rodata + .data，落在 0x1000 起的 DMEM）"
$OBJCOPY -O binary -j .rodata -j .data prog.elf prog.data

echo "==> 转数据 hex（其余补 0）"
python3 bin2hex.py prog.data prog_data.hex 4096 00000000

echo "==> 反汇编"
$OBJDUMP -d prog.elf > prog.dis

echo
echo "== 产物 =="
ls -l prog.elf prog.bin prog.hex prog_data.hex
echo
echo "== 大小检查（IMEM 4KB / DMEM 4KB）=="
echo "   代码+只读数据: $(stat -c%s prog.bin) 字节"
echo
echo "== 反汇编 =="
cat prog.dis
