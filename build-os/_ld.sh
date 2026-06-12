#!/bin/bash
# Rebuild only ld after patching the binutils-trunk cmdline_check_object_only_section abort().
set -e
BD=~/rvlinux/build/build-riscv32ima-linux/build-binutils-linux
LOG=~/rvlinux/ld_rebuild.log
echo "== rebuild ld $(date) ==" | tee "$LOG"
cd "$BD/ld"
make -j4 >> "$LOG" 2>&1
echo "== install ld ==" | tee -a "$LOG"
make install >> "$LOG" 2>&1
NEWLD=~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-ld
ls -la "$NEWLD"
# quick smoke test: -r on a trivial object must no longer abort
T=$(mktemp -d)
echo 'int x;' > "$T/a.c"
~/rvlinux/toolchain/riscv32ima-linux/bin/riscv32-unknown-linux-gnu-gcc -march=rv32ima -mabi=ilp32 -c "$T/a.c" -o "$T/a.o"
if "$NEWLD" -r "$T/a.o" -o "$T/a-r.o" 2>"$T/err"; then
  echo "LD -r OK"
else
  echo "LD -r STILL FAILS:"; cat "$T/err"
fi
rm -rf "$T"
