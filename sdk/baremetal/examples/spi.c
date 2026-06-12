// 裸机:SPI 发几个字节(效果在波形 spi_clk/spi_mosi/spi_cs 上看)
// 注:tb 把 spi_miso 接了 1,所以收回的数据是 0xff;主要演示发送时序。
#include "../bm.h"

int main(void)
{
    uart_puts("\n==== 裸机 SPI 演示 ====\n");
    spi_init();
    uart_puts("SPI 已初始化(主模式)。发送字节(看波形 spi_clk/mosi/cs)...\n");

    uint8_t tx[] = {0xde, 0xad, 0xbe, 0xef};
    for (int i = 0; i < 4; i++) {
        uint8_t rx = spi_xfer(tx[i]);
        uart_puts("  发 ");
        uart_puthex(tx[i]);
        uart_puts("  收 ");
        uart_puthex(rx);
        uart_puts("\n");
    }
    uart_puts("==== done ====\n");
    return 0;
}
