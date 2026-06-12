//-----------------------------------------------------------------
// mmio.h —— Linux 用户态直接访问外设(经 /dev/mem mmap 物理寄存器)。
// 和裸机一样读写 UART/SPI/GPIO,但程序跑在 Linux 里、需 root + /dev/mem。
// 寄存器偏移/位定义共用 ../soc.h。
//-----------------------------------------------------------------
#ifndef LINUX_MMIO_H
#define LINUX_MMIO_H
#include "../soc.h"
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

// 把某个外设的物理基址 mmap 进来,返回可直接 REG32() 的指针;失败返回 NULL。
static inline volatile void *mmio_map(uint32_t phys_base)
{
    static int fd = -1;
    if (fd < 0) {
        fd = open("/dev/mem", O_RDWR | O_SYNC);
        if (fd < 0) { perror("open /dev/mem(需 root + CONFIG_DEVMEM + /dev/mem 节点)"); return NULL; }
    }
    void *p = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)phys_base);
    if (p == MAP_FAILED) { perror("mmap"); return NULL; }
    return (volatile void *)p;
}

#endif // LINUX_MMIO_H
