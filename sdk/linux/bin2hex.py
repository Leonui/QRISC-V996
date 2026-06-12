#!/usr/bin/env python3
# 把一个原始二进制(这里是程序 cpio)转成 $readmemh 用的 hex,
# 落在 DRAM 的指定物理地址(虚拟磁盘区域 = DRAM 顶部)。
# 输出带 @词偏移,所以可以和内核 image.hex 装进同一片 mem 而不冲突。
#   bin2hex.py <in.bin> <out.hex> <load_addr> [mem_base]
import sys

inp, out = sys.argv[1], sys.argv[2]
load = int(sys.argv[3], 0)
base = int(sys.argv[4], 0) if len(sys.argv) > 4 else 0x80000000
assert load >= base and (load - base) % 4 == 0, "load addr must be word-aligned >= base"

data = open(inp, "rb").read()
if len(data) % 4:                         # 补齐到 4 字节
    data += b"\x00" * (4 - len(data) % 4)

word0 = (load - base) // 4
with open(out, "w") as f:
    f.write("@%08x\n" % word0)            # 起始词偏移
    for i in range(0, len(data), 4):
        w = int.from_bytes(data[i:i+4], "little")   # 小端(和核一致)
        f.write("%08x\n" % w)
print("wrote %s : %d bytes @0x%08x (word @0x%x)" % (out, len(data), load, word0))
