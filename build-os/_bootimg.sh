#!/bin/bash
# Stage 5: package vmlinux + dtb into a biRISC-V-bootable ELF via riscv-linux-boot.
# Produces riscv-linux-boot.elf (load @0x80000000) with the SBI bootloader that
# emulates atomics for the biRISC-V (RV32IM) core and provides hvc0 console.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
# SBI 引导器:默认用工程内的 bootloader/,可用 BOOT 环境变量覆盖。
BOOT="${BOOT:-$(cd "$HERE/../bootloader" && pwd)}"
TCBIN=~/rvlinux/toolchain/riscv32ima-linux/bin
TCPREFIX="$TCBIN/riscv32-unknown-linux-gnu-"
LINUX="${LINUX:-$HOME/rvlinux/linux-5.4}"
# DTS:由 build_image.sh 经 DTS 环境变量传入(选定的控制台变体);默认 hvc0。
DTS="${DTS:-$HERE/dts/config32_hvc0.dts}"
LOG="${BOOTIMG_LOG:-$HOME/rvlinux/bootimg_build.log}"

cd "$BOOT"
# NB: `make clean` aborts without VMLINUX set (makefile ${error}), so remove the
# generated artifacts by hand - otherwise a stale vmlinux.bin (e.g. left by the
# prebuilt diagnostic) is newer than our vmlinux and make skips the objcopy.
rm -f vmlinux.bin config.dtb riscv-linux-boot.elf
rm -rf obj
echo "== build riscv-linux-boot.elf $(date) ==" | tee "$LOG"
make \
  TOOLCHAIN_PREFIX="$TCPREFIX" \
  VMLINUX="$LINUX/vmlinux" \
  DTS_FILE="$DTS" \
  LINUX_DIR="$LINUX" \
  >> "$LOG" 2>&1
rc=$?
echo "== boot make rc=$rc ==" | tee -a "$LOG"
if [ -f riscv-linux-boot.elf ]; then
  ls -la riscv-linux-boot.elf vmlinux.bin config.dtb
  file riscv-linux-boot.elf
  # sanity: the bootloader image itself must contain NO hardware atomics (core has no A)
  n=$("$TCPREFIX"objdump -d obj/*.o 2>/dev/null | grep -cE '\b(amo|lr\.|sc\.)' || true)
  echo "atomic-insn count in bootloader objects: $n"
  echo "BOOTIMG OK"
else
  echo "BOOTIMG FAILED rc=$rc"; tail -25 "$LOG"
fi
