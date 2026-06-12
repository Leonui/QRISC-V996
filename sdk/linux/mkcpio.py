#!/usr/bin/env python3
# 把一个目录打成 newc 格式 cpio(目标端 busybox `cpio -idmu` 能解)。
# 主机不一定装了 cpio,所以自己生成,免依赖。
#   mkcpio.py <dir> <out.cpio>
import os, sys

src, out = sys.argv[1], sys.argv[2]

def hdr(name, data, mode, ino):
    namesize = len(name) + 1
    fields = [
        0x070701,           # magic 是字符串,后面单独写
    ]
    h = "070701"
    h += "%08X" % ino                 # ino
    h += "%08X" % mode                # mode
    h += "%08X" % 0                   # uid
    h += "%08X" % 0                   # gid
    h += "%08X" % 1                   # nlink
    h += "%08X" % 0                   # mtime
    h += "%08X" % len(data)           # filesize
    h += "%08X" % 0                   # devmajor
    h += "%08X" % 0                   # devminor
    h += "%08X" % 0                   # rdevmajor
    h += "%08X" % 0                   # rdevminor
    h += "%08X" % namesize            # namesize
    h += "%08X" % 0                   # check
    blob = h.encode() + name.encode() + b"\x00"
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)        # name 后补 4 对齐
    blob += data
    blob += b"\x00" * ((4 - len(blob) % 4) % 4)        # data 后补 4 对齐
    return blob

buf = b""
ino = 1
for fn in sorted(os.listdir(src)):
    p = os.path.join(src, fn)
    if not os.path.isfile(p):
        continue
    data = open(p, "rb").read()
    mode = 0o100755 if os.access(p, os.X_OK) else 0o100644
    buf += hdr(fn, data, mode, ino)
    ino += 1

# trailer
buf += hdr("TRAILER!!!", b"", 0, 0)
open(out, "wb").write(buf)
print("cpio: %d files, %d bytes -> %s" % (ino - 1, len(buf), out))
