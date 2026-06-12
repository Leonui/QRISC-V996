#!/bin/bash
#-----------------------------------------------------------------
# 打包一个可引导镜像,选择控制台变体:
#   ./build_image.sh hvc0     控制台经 SBI(hvc0)—— 稳定、完整可交互【默认】
#   ./build_image.sh ttyul0   控制台经内核 uartlite 驱动(ttyUL0)—— 真驱动【WIP】
#
# 两个变体共用同一个 vmlinux(内核已编入 uartlite + Xilinx INTC 驱动);只有 dtb 不同。
# 产物:image/biriscv-linux-5.4-<变体>.elf
#-----------------------------------------------------------------
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
VARIANT="${1:-hvc0}"

case "$VARIANT" in
  hvc0)   DTS="$HERE/dts/config32_hvc0.dts" ;;
  ttyul0) DTS="$HERE/dts/config32_ttyul0.dts" ;;
  *) echo "用法: $0 [hvc0|ttyul0]"; exit 1 ;;
esac

echo "== 变体: $VARIANT  ($(grep -o 'console=[^ ]*' "$DTS")) =="

# 把选定变体的 dts 传给 _bootimg.sh;它用工程内 vendoring 的 SBI 引导器构建。
BOOT="${BOOT:-$(cd "$HERE/../bootloader" && pwd)}"
DTS="$DTS" bash "$HERE/_bootimg.sh"

mkdir -p "$ROOT/image"
OUT="$ROOT/image/biriscv-linux-5.4-$VARIANT.elf"
cp "$BOOT/riscv-linux-boot.elf" "$OUT"
echo "✅ 产物: $OUT"
echo "   跑它(tb_soc):  ELF=$OUT ./tb/tb_soc/run.sh"
