#-----------------------------------------------------------------
# run_jtag.tcl - QRISC-V996 ZCU104 bring-up over JTAG.
#
#   xsct run_jtag.tcl <bitstream.bit> <fsbl.elf> <riscv_image.bin> <ps_app.elf>
#
# Watch the RISC-V console on ttyUSB1 @115200 (e.g. picocom -b 115200 /dev/ttyUSB1).
#-----------------------------------------------------------------
if {$argc != 4} {
    puts stderr "usage: xsct run_jtag.tcl <bit> <fsbl.elf> <riscv.bin> <ps_app.elf>"
    exit 1
}
set bit      [file normalize [lindex $argv 0]]
set fsbl     [file normalize [lindex $argv 1]]
set riscv    [file normalize [lindex $argv 2]]
set ps_app   [file normalize [lindex $argv 3]]
set RISCV_DDR 0x40000000

foreach f [list $bit $fsbl $riscv $ps_app] {
    if {![file exists $f]} { puts stderr "ERROR: missing $f"; exit 1 }
}

puts "INFO: connecting to hw_server..."
connect

puts "INFO: system reset to clear any wedged state"
targets -set -filter {name =~ "PSU"}
catch { rst -system }
after 2000

puts "INFO: programming PL with $bit"
targets -set -filter {name =~ "*PL*"}
fpga -file $bit
after 300

puts "INFO: running FSBL for full PS init"
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor
after 300
dow $fsbl
con
after 5000
stop

puts "INFO: loading RISC-V image -> DDR $RISCV_DDR"
targets -set -filter {name =~ "Cortex-A53 #0"}
dow -data $riscv $RISCV_DDR

puts "INFO: downloading + running ps_app.elf on A53#0"
dow $ps_app
con

puts "------------------------------------------------------------"
puts "INFO: RISC-V released by ps_app; console is on ttyUSB1 @115200."
puts "INFO:   picocom -b 115200 /dev/ttyUSB1"
puts "------------------------------------------------------------"
# Leave the target running; do not disconnect.
