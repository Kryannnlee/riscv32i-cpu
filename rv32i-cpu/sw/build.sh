#!/usr/bin/env bash
# 编译 C 程序 -> ELF -> 裸二进制 -> $readmemh 用的 hex
# 在 VM 里执行：  bash build.sh
set -euo pipefail
cd "$(dirname "$0")"

CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
OBJDUMP=${OBJDUMP:-riscv64-unknown-elf-objdump}

CFLAGS="-march=rv32i -mabi=ilp32 -O2 -nostdlib -nostartfiles -T link.ld"

echo "==> 编译"
$CC $CFLAGS start.S main.c -o prog.elf

echo "==> 转裸二进制"
$OBJCOPY -O binary prog.elf prog.bin

echo "==> 转 hex"
python3 bin2hex.py prog.bin prog.hex

echo "==> 反汇编"
$OBJDUMP -d prog.elf > prog.dis

echo
echo "== 产物 =="
ls -l prog.elf prog.bin prog.hex
echo
echo "== 大小检查（IMEM 4KB / DMEM 4KB）=="
echo "   代码+只读数据: $(stat -c%s prog.bin) 字节"
echo
echo "== 反汇编 =="
cat prog.dis
