#!/usr/bin/env python3
"""把 objcopy 出来的裸二进制转成 $readmemh 用的文本格式

用法：
    bin2hex.py <in.bin> <out.hex> [字数] [填充值]

    字数   默认 2048（= IMEM/DMEM 的深度，8KB）
    填充值 默认 00000013（NOP），数据段用 00000000

输出：每行一个 32 位字，8 位十六进制，**小端**（低字节在低地址）。
例：字节序列 13 00 00 00  ->  一行 "00000013"

为什么要补齐：
  $readmemh 只填文件里有的位置，其余保持原值。仿真里没问题（前面先填过），
  但综合时 Vivado 不保证 initial 块的执行顺序，没填到的位置可能是 X。
  所以直接输出完整的 1024 个字，把未用部分填成 NOP 或 0。
  字数必须和 rtl/imem.sv、rtl/dmem.sv 的数组深度一致。
"""
import struct
import sys

if len(sys.argv) < 3:
    print("usage: bin2hex.py <in.bin> <out.hex> [words] [pad_hex]")
    sys.exit(1)

words_total = int(sys.argv[3]) if len(sys.argv) > 3 else 2048
pad_word    = int(sys.argv[4], 16) if len(sys.argv) > 4 else 0x00000013

data = open(sys.argv[1], "rb").read()
data += b"\x00" * ((-len(data)) % 4)      # 补到 4 字节对齐

words = [struct.unpack("<I", data[i:i + 4])[0]
         for i in range(0, len(data), 4)]

if len(words) > words_total:
    sys.exit("内容太大：%d 字 > 容量 %d 字" % (len(words), words_total))

used = len(words)
words += [pad_word] * (words_total - used)

open(sys.argv[2], "w").write("\n".join("%08x" % w for w in words) + "\n")
print("%d 个字，补齐到 %d -> %s" % (used, words_total, sys.argv[2]))
