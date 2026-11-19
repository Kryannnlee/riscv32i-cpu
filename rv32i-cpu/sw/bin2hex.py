#!/usr/bin/env python3
"""把 objcopy 出来的裸二进制转成 $readmemh 用的文本格式

输出格式：每行一个 32 位字，8 位十六进制，**小端**（低字节在低地址）。
例：字节序列 13 00 00 00  ->  一行 "00000013"

为什么要补齐到 IMEM_WORDS：
  $readmemh 只填文件里有的那些位置，其余保持原值。仿真里没问题（前面先填了 NOP），
  但综合时 Vivado 不保证 initial 块的执行顺序，没填到的位置可能是 X。
  所以这里直接输出完整的 1024 个字，程序后面全部补 NOP。
  IMEM_WORDS 必须和 rtl/imem.sv 的 `mem [0:1023]` 一致。
"""
import struct
import sys

IMEM_WORDS = 1024
NOP = 0x00000013          # addi x0, x0, 0

if len(sys.argv) != 3:
    print("usage: bin2hex.py <in.bin> <out.hex>")
    sys.exit(1)

data = open(sys.argv[1], "rb").read()
data += b"\x00" * ((-len(data)) % 4)      # 补到 4 字节对齐

words = [struct.unpack("<I", data[i:i + 4])[0]
         for i in range(0, len(data), 4)]

if len(words) > IMEM_WORDS:
    sys.exit("程序太大：%d 字 > IMEM 容量 %d 字" % (len(words), IMEM_WORDS))

used = len(words)
words += [NOP] * (IMEM_WORDS - used)

open(sys.argv[2], "w").write("\n".join("%08x" % w for w in words) + "\n")
print("%d 条指令，补齐到 %d 字 -> %s" % (used, IMEM_WORDS, sys.argv[2]))
