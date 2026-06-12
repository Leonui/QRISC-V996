//-----------------------------------------------------------------
// bm.h —— 裸机外设驱动(直接读写物理 MMIO,MMU 关)。
// UART / GPIO / SPI 的简单操作 + 打印帮手。
//-----------------------------------------------------------------
#ifndef BM_H
#define BM_H
#include "../soc.h"

//================= UART =================
static inline void uart_putc(char c)
{
    while (REG32(UART_BASE, UART_STATUS) & UART_ST_TXFULL) {}   // 等 TX 不满
    REG32(UART_BASE, UART_TX) = (uint8_t)c;
}
static inline void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n') uart_putc('\r');                       // \n -> \r\n
        uart_putc(*s++);
    }
}
static inline int uart_getc_nb(void)                            // 非阻塞:无字符返回 -1
{
    if (REG32(UART_BASE, UART_STATUS) & UART_ST_RXVALID)
        return (int)(REG32(UART_BASE, UART_RX) & 0xff);
    return -1;
}
static inline void uart_puthex(uint32_t v)                     // 打印 8 位十六进制
{
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uint32_t nib = (v >> i) & 0xf;
        uart_putc(nib < 10 ? ('0' + nib) : ('a' + nib - 10));
    }
}

//================= GPIO =================
// dir: 1=输出 0=输入(按位)。设方向后用 gpio_write 驱动输出引脚。
static inline void gpio_set_dir(uint32_t mask)  { REG32(GPIO_BASE, GPIO_DIRECTION) = mask; }
static inline void gpio_write(uint32_t val)     { REG32(GPIO_BASE, GPIO_OUTPUT)    = val; }
static inline uint32_t gpio_read(void)          { return REG32(GPIO_BASE, GPIO_INPUT); }

//================= SPI (Xilinx AXI SPI) =================
static inline void spi_init(void)
{
    REG32(SPI_BASE, SPI_SRR) = 0x0000000a;                      // 软复位
    REG32(SPI_BASE, SPI_SSR) = 0xffffffff;                      // 先全不选(低有效)
    // 使能 + 主模式 + 复位收发 FIFO
    REG32(SPI_BASE, SPI_CR)  = SPI_CR_ENABLE | SPI_CR_MASTER | SPI_CR_TXRST | SPI_CR_RXRST;
}
// 选中从设备0、发一字节、收一字节(全双工)
static inline uint8_t spi_xfer(uint8_t tx)
{
    REG32(SPI_BASE, SPI_SSR) = ~1u;                             // 选从0(对应位拉低)
    REG32(SPI_BASE, SPI_DTR) = tx;
    while (REG32(SPI_BASE, SPI_SR) & SPI_SR_RXEMPTY) {}         // 等收到
    uint8_t rx = REG32(SPI_BASE, SPI_DRR) & 0xff;
    REG32(SPI_BASE, SPI_SSR) = 0xffffffff;                      // 取消选中
    return rx;
}

//================= 杂项 =================
static inline uint32_t timer_now(void) { return REG32(TIMER_BASE, TIMER_VALUE); }
static inline void delay(uint32_t n)   { for (volatile uint32_t i = 0; i < n; i++) {} }

#endif // BM_H
