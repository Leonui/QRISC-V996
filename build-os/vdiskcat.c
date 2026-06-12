/* vdiskcat —— 把虚拟磁盘区(DRAM 0x82000000,内核 RAM 之外)经 /dev/mem mmap 读出,
 * 原样写到 stdout。下游 `cpio -idmu` 读到 TRAILER 自停,SIGPIPE 让本程序结束。
 * 为什么用 mmap 而不是 dd:/dev/mem 的 read() 只能读内核线性映射的 RAM,
 * 读不到 RAM 之外;mmap 可以映射任意物理地址(和 gpio_mmap 访问外设同理)。
 * 这个助手是稳定基础设施,编一次烤进 initramfs;改磁盘上的程序不用动它。 */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>

#define DISK_ADDR  0x82000000UL
#define DISK_SIZE  (4UL * 1024 * 1024)

int main(void)
{
    int fd = open("/dev/mem", O_RDONLY);
    if (fd < 0) { perror("open /dev/mem"); return 1; }
    const char *p = mmap(0, DISK_SIZE, PROT_READ, MAP_SHARED, fd, DISK_ADDR);
    if (p == MAP_FAILED) { perror("mmap"); return 1; }
    unsigned long off = 0;
    while (off < DISK_SIZE) {
        ssize_t n = write(1, p + off, DISK_SIZE - off);
        if (n <= 0) break;          /* cpio 解完会关管道 -> SIGPIPE/EPIPE -> 结束 */
        off += (unsigned long)n;
    }
    return 0;
}
