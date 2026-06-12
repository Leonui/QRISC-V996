#!/bin/bash
#-----------------------------------------------------------------
# 编译 Linux 用户态程序,装进 rootfs,并重建镜像。
# 因为根文件系统是 initramfs(嵌在内核里、内存只读),程序必须在构建时烤进去,
# 没法运行时拷文件(无网络/磁盘)。所以"编译 + 装入 + 重建内核/镜像"是一步。
#
#   ./build_install.sh                编译 examples/ 下所有 .c,装进 rootfs/usr/bin,重建镜像
#   ./build_install.sh hello.c        只编一个
#   ./build_install.sh --no-rebuild   只编译+拷进 rootfs,不重建镜像(攒多个程序后一次重建)
#-----------------------------------------------------------------
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
CC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-gcc
ROOTFS=~/rvlinux/rootfs
DEST="$ROOTFS/usr/bin"

command -v "$CC" >/dev/null || { echo "缺 Linux 工具链: $CC"; exit 1; }
mkdir -p "$DEST" "$HERE/build"

# 选要编的源文件
if [ -n "$1" ] && [ "$1" != "--no-rebuild" ]; then SRCS="$HERE/examples/$1"; else SRCS="$HERE/examples/"*.c; fi

echo "== 编译 Linux 程序(静态)并装进 $DEST =="
for src in $SRCS; do
    [ -f "$src" ] || continue
    name=$(basename "$src" .c)
    "$CC" -march=rv32ima -mabi=ilp32 -O2 -static -Wall "$src" -o "$HERE/build/$name"
    cp "$HERE/build/$name" "$DEST/$name"
    echo "  $name -> /usr/bin/$name  ($(stat -c%s "$DEST/$name") B)"
done

if [ "$1" = "--no-rebuild" ] || [ "$2" = "--no-rebuild" ]; then
    echo "(--no-rebuild:已装进 rootfs,稍后手动重建镜像)"; exit 0
fi

echo "== 重建内核(增量,重新嵌入 rootfs)+ 两个镜像 =="
TC=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-
( cd ~/rvlinux/linux-5.4 && make ARCH=riscv CROSS_COMPILE="$TC" HOSTCFLAGS="-fcommon" \
       KCFLAGS="-Wno-error -fcommon" -j4 vmlinux >/dev/null 2>&1 )
bash "$ROOT/build-os/build_image.sh" hvc0   >/dev/null
bash "$ROOT/build-os/build_image.sh" ttyul0 >/dev/null
cp "$ROOT/image/biriscv-linux-5.4-hvc0.elf" "$ROOT/image/biriscv-linux-5.4.elf"
python3 "$ROOT/scripts/make_hex.py" "$ROOT/image/biriscv-linux-5.4.elf" "$ROOT/tb/tb_soc/image.hex" 0x80000000 >/dev/null
echo "✅ 完成。在 Linux shell 里直接敲程序名运行(如  hello  /  gpio_mmap)。"
echo "   /dev/mem 类程序需 root(本系统默认 root)。"