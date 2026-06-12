//-----------------------------------------------------------------
// soc.h —— biRISC-V + riscv_soc 的外设寄存器定义(裸机 / Linux 共用)
//
// 地址映射(axi4_lite_tap 译码):
//   0x90000000  irq_ctrl (Xilinx INTC)
//   0x91000000  timer
//   0x92000000  uart_lite        ← 控制台
//   0x93000000  spi_lite  (Xilinx SPI)
//   0x94000000  gpio
//   0x80000000  DRAM (32MB)
//
// 用法:
//   裸机   —— MMU 关,物理地址 = 指针,直接用下面的 *_BASE。
//   Linux  —— 经 /dev/mem mmap,把映射回来的指针当 base(见 sdk/linux/mmio.h)。
//-----------------------------------------------------------------
#ifndef SOC_H
#define SOC_H
#include <stdint.h>

#define REG32(base, off)  (*(volatile uint32_t *)((uintptr_t)(base) + (off)))

//============================ 外设基址 ============================
#define IRQ_BASE   0x90000000u
#define TIMER_BASE 0x91000000u
#define UART_BASE  0x92000000u
#define SPI_BASE   0x93000000u
#define GPIO_BASE  0x94000000u

//============================ UART (uart_lite) ============================
#define UART_RX       0x00      // 读:接收数据
#define UART_TX       0x04      // 写:发送数据
#define UART_STATUS   0x08      // bit0=RX有效, bit3=TX满
#define UART_CONTROL  0x0c      // bit0=复位TX, bit1=复位RX, bit4=中断使能
#define UART_ST_RXVALID  (1u<<0)
#define UART_ST_TXFULL   (1u<<3)
#define UART_CTL_IE      (1u<<4)

//============================ GPIO ============================
#define GPIO_DIRECTION  0x00    // 1=输出, 0=输入(按位)
#define GPIO_INPUT      0x04    // 读:输入电平
#define GPIO_OUTPUT     0x08    // 写:输出电平

//============================ SPI (Xilinx AXI SPI) ============================
#define SPI_SRR   0x40   // 软复位(写 0x0a)
#define SPI_CR    0x60   // 控制寄存器
#define SPI_SR    0x64   // 状态寄存器
#define SPI_DTR   0x68   // 发送数据
#define SPI_DRR   0x6c   // 接收数据
#define SPI_SSR   0x70   // 从设备选择(低有效)
#define SPI_CR_ENABLE     (1u<<1)   // SPE
#define SPI_CR_MASTER     (1u<<2)
#define SPI_CR_TXRST      (1u<<5)
#define SPI_CR_RXRST      (1u<<6)
#define SPI_SR_TXEMPTY    (1u<<2)
#define SPI_SR_RXEMPTY    (1u<<0)

//============================ Timer ============================
#define TIMER_VALUE 0x00   // 读:当前计数(自由计数器)

#endif // SOC_H
